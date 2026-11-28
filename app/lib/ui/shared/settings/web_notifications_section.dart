import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logging/app_log.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../notifications/push_plan_uploader.dart';
import '../../../notifications/web_push_renewer.dart';
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

  /// The failure was turning off (else turning on).
  bool _failedTurnOff = false;

  /// Bumped by each load, so an older one that finishes late is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  WebPushClient get _client => ref.read(webPushClientProvider);

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  SyncApi? get _api =>
      ref.read(syncControllerProvider.notifier).pushContext?.api;

  void _set(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final status = await ref.read(webPushRenewerProvider).check();
    if (!mounted || generation != _generation) return;
    setState(() {
      _failed = status == WebPushStatus.failed;
      _failedTurnOff = false;
      _phase = switch (status) {
        WebPushStatus.unsupported => _Phase.unsupported,
        WebPushStatus.needsHomeScreen => _Phase.needsHomeScreen,
        WebPushStatus.signedOut => _Phase.signedOut,
        WebPushStatus.notConfigured => _Phase.notConfigured,
        WebPushStatus.denied => _Phase.denied,
        WebPushStatus.off || WebPushStatus.failed => _Phase.off,
        WebPushStatus.on => _Phase.on,
      };
    });
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
      _failedTurnOff = false;
    });
    var subscribed = false;
    try {
      // Straight from the tap: iOS only asks then.
      final permission = await _client.requestPermission();
      if (permission == 'denied') return _set(_Phase.denied);
      if (permission != 'granted') return;
      String key;
      try {
        key = await api.pushKey();
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
      await _settings.setWebPushWanted(true);
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
      _failedTurnOff = false;
    });
    try {
      // Not renewed by itself again, whatever happens below.
      await _settings.setWebPushWanted(false);
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
      if (mounted) {
        setState(() {
          _failed = true;
          _failedTurnOff = true;
        });
      }
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

    final failure = row(
      Icons.error_outline,
      _failedTurnOff ? l10n.webNotifTurnOffFailed : l10n.webNotifFailed,
      color: theme.colorScheme.error,
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
        if (_failed) failure,
        button(
          FilledButton.icon(
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(l10n.webNotifTurnOn),
            onPressed: _busy ? null : _turnOn,
          ),
        ),
      ],
      _Phase.on => [
        if (_failed) failure,
        if (ref.watch(ownPushPlanFailedProvider))
          row(
            Icons.error_outline,
            l10n.webNotifPlanFailed,
            color: theme.colorScheme.error,
          )
        else
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
