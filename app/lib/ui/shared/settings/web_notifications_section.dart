import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logging/app_log.dart';
import '../../../notifications/push_plan_uploader.dart';
import '../../../platform/web_push.dart';
import '../../../state/providers.dart';
import '../../../sync/sync_api.dart';
import '../../../sync/sync_controller.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import '../web/add_to_home_screen_page.dart';

/// docs/self-hosting.md, "Web reminders": how to give a server VAPID keys.
const webRemindersDocsUrl =
    'https://github.com/Krkr8/taskwise/blob/main/docs/self-hosting.md#web-reminders';

enum _Phase {
  loading,
  unsupported,
  needsHomeScreen,
  signedOut,
  notConfigured,
  denied,
  off,
  on,
}

/// Settings → Notifications on the web (Brutal and Lapis): turns Web Push on
/// or off for this browser. Turning on asks for the permission, subscribes
/// with the server's VAPID key, saves the subscription on the server
/// (`PUT /push/subscription`) and uploads this browser's push plan at once.
/// The server then sends each reminder at its time (docs/sync-api.md).
class WebNotificationsSection extends ConsumerStatefulWidget {
  const WebNotificationsSection({super.key});

  @override
  ConsumerState<WebNotificationsSection> createState() =>
      _WebNotificationsSectionState();
}

class _WebNotificationsSectionState
    extends ConsumerState<WebNotificationsSection> {
  _Phase _phase = _Phase.loading;
  bool _busy = false;
  bool _failed = false;

  /// The server's VAPID public key, once fetched.
  String? _key;

  /// Bumped by each load, so an older one that finishes late is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  WebPushClient get _client => ref.read(webPushClientProvider);

  SyncApi? get _api =>
      ref.read(syncControllerProvider.notifier).pushContext?.api;

  void _set(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    bool stale() => !mounted || generation != _generation;
    try {
      final support = await _client.support();
      if (stale()) return;
      if (support != WebPushSupport.supported) {
        return _set(
          support == WebPushSupport.needsHomeScreen
              ? _Phase.needsHomeScreen
              : _Phase.unsupported,
        );
      }
      final api = _api;
      if (api == null) return _set(_Phase.signedOut);
      try {
        _key = await api.pushKey();
      } on SyncHttpException catch (e) {
        // 404: no VAPID keys, or a server from before web reminders.
        if (e.status == 404) {
          if (!stale()) _set(_Phase.notConfigured);
          return;
        }
        appLog.warning('push', 'No push key: ${e.status} ${e.code}');
      } on SyncNetworkException catch (e) {
        // Offline: asked again when turning on.
        appLog.warning('push', 'No push key: ${e.message}');
      }
      if (stale()) return;
      final permission = await _client.permission();
      if (stale()) return;
      if (permission == 'denied') return _set(_Phase.denied);
      final subscription = await _client.current();
      if (stale()) return;
      if (subscription == null || permission != 'granted') {
        return _set(_Phase.off);
      }
      // Made with another server's key: it can never get pushes from this
      // one, and must not be handed to this account.
      final made = subscription.applicationServerKey;
      final server = _key;
      if (made != null &&
          server != null &&
          made.replaceAll('=', '') != server.replaceAll('=', '')) {
        appLog.info('push', 'The browser subscription is for another server');
        await _client.unsubscribe();
        if (!stale()) _set(_Phase.off);
        return;
      }
      _set(_Phase.on);
      // Offline (no key): can't tell whose it is, so don't send it.
      if (server != null) await _resendIfServerLost(api, subscription);
    } on Object catch (e, stack) {
      appLog.error('push', e, stack);
      if (!stale()) _set(_Phase.off);
    }
  }

  /// Subscribed here, but the server lists this device without a
  /// subscription (it signed in again, or the push service once said it was
  /// gone): send it again.
  Future<void> _resendIfServerLost(
    SyncApi api,
    WebPushSubscription subscription,
  ) async {
    final devices = ref.read(syncControllerProvider).serverDevices;
    final me = ref.read(deviceIdProvider);
    final own = devices?.where((d) => d.id == me).firstOrNull;
    if (own == null || own.pushEnabled) return;
    try {
      await _save(api, subscription);
    } on SyncApiException catch (e) {
      appLog.warning('push', 'Could not send the subscription again: $e');
    }
  }

  Future<void> _save(SyncApi api, WebPushSubscription subscription) async {
    await api.putPushSubscription(
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
    );
    appLog.info('push', 'This browser gets reminders now');
    await _afterChange();
  }

  /// The plan follows the subscription, and the device list shows it.
  Future<void> _afterChange() async {
    await ref.read(pushPlanUploaderProvider).uploadNow();
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  Future<void> _turnOn() async {
    final api = _api;
    if (api == null) return _set(_Phase.signedOut);
    setState(() {
      _busy = true;
      _failed = false;
    });
    var subscribed = false;
    try {
      // Straight from the tap: iOS only asks then.
      final permission = await _client.requestPermission();
      if (permission == 'denied') return _set(_Phase.denied);
      if (permission != 'granted') return;
      String key;
      try {
        key = _key ??= await api.pushKey();
      } on SyncHttpException catch (e) {
        if (e.status != 404) rethrow;
        return _set(_Phase.notConfigured);
      }
      final subscription = await _client.subscribe(key);
      if (subscription == null) throw StateError('No subscription');
      subscribed = true;
      await api.putPushSubscription(
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
      );
      appLog.info('push', 'Notifications turned on in this browser');
      _set(_Phase.on);
      await _afterChange();
    } on Object catch (e, stack) {
      if (e is SyncApiException) {
        appLog.warning('push', 'Turning on failed: $e');
      } else {
        appLog.error('push', e, stack);
      }
      // The server doesn't know this subscription: drop it, so the next
      // try starts clean and "off" is the truth.
      if (subscribed) {
        try {
          await _client.unsubscribe();
        } on Object catch (e, stack) {
          appLog.error('push', e, stack);
        }
      }
      if (mounted) {
        setState(() {
          _phase = _Phase.off;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final subscription = await _client.current();
      final api = _api;
      if (subscription != null && api != null) {
        try {
          await api.deletePushSubscription(subscription.endpoint);
        } on SyncApiException catch (e) {
          // Pushes to a dropped subscription fail, and the server forgets
          // it then (docs/sync-api.md).
          appLog.warning('push', 'Could not remove the subscription: $e');
        }
      }
      await _client.unsubscribe();
      appLog.info('push', 'Notifications turned off in this browser');
      _set(_Phase.off);
      await _afterChange();
    } on Object catch (e, stack) {
      appLog.error('push', e, stack);
      // Part of it may have happened: show what is true now.
      await _load();
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showGuide() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) =>
          AddToHomeScreenPage(onContinue: () => Navigator.of(context).pop()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Signing in or out changes what this shows.
    ref.listen(
      syncControllerProvider.select((s) => s.connected),
      (_, _) => unawaited(_load()),
    );
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget row(IconData icon, String text, {String? subtitle, Color? color}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(text),
          subtitle: subtitle == null ? null : Text(subtitle),
        );
    Widget button(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );

    final children = switch (_phase) {
      _Phase.loading => [
        const Padding(
          padding: EdgeInsets.all(Spacing.md),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
      _Phase.unsupported => [
        row(Icons.notifications_off_outlined, l10n.webNotifUnsupported),
      ],
      _Phase.needsHomeScreen => [
        row(Icons.add_to_home_screen, l10n.webNotifNeedsHomeScreen),
        button(
          OutlinedButton(
            key: const ValueKey('web-notif-guide'),
            onPressed: _showGuide,
            child: Text(l10n.webNotifHowToAdd),
          ),
        ),
      ],
      _Phase.signedOut => [
        row(Icons.notifications_off_outlined, l10n.webNotifSignIn),
      ],
      _Phase.notConfigured => [
        row(Icons.notifications_off_outlined, l10n.webNotifNotConfigured),
        button(
          TextButton.icon(
            key: const ValueKey('web-notif-setup'),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.webNotifSetupLink),
            onPressed: () => unawaited(
              launchUrl(
                Uri.parse(webRemindersDocsUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ),
      ],
      _Phase.denied => [
        row(Icons.block, l10n.webNotifDenied, color: theme.colorScheme.error),
      ],
      _Phase.off => [
        if (_failed)
          row(
            Icons.error_outline,
            l10n.webNotifFailed,
            color: theme.colorScheme.error,
          ),
        button(
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(l10n.webNotifTurnOn),
            onPressed: _busy ? null : _turnOn,
          ),
        ),
      ],
      _Phase.on => [
        if (_failed)
          row(
            Icons.error_outline,
            l10n.webNotifFailed,
            color: theme.colorScheme.error,
          ),
        row(
          Icons.notifications_active_outlined,
          l10n.webNotifOn,
          subtitle: _plannedText(l10n),
          color: theme.colorScheme.primary,
        ),
        button(
          OutlinedButton(
            onPressed: _busy ? null : _turnOff,
            child: Text(l10n.webNotifTurnOff),
          ),
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// "Reminders planned until Sun, Dec 20" (with the year when it isn't
  /// this one), or "No upcoming reminders".
  String _plannedText(AppLocalizations l10n) {
    final end = ref.watch(ownPushPlanEndProvider);
    if (end == null) return l10n.webNotifNoUpcoming;
    final now = ref.read(clockProvider)();
    final pattern = end.year == now.year
        ? DateFormat.MMMEd(l10n.localeName)
        : DateFormat.yMMMEd(l10n.localeName);
    return l10n.webNotifPlannedUntil(pattern.format(end));
  }
}
