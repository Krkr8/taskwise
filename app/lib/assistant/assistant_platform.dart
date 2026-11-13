import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../logging/app_log.dart';

/// Something the phone asked Taskwise to do from outside the app.
sealed class AssistantAction {
  const AssistantAction();
}

/// Android's "New task" shortcut (long-press the app icon): show the
/// quick-add field.
final class NewTaskAction extends AssistantAction {
  const NewTaskAction();
}

/// Text shared to Taskwise from another app (Android's share sheet).
final class SharedTextAction extends AssistantAction {
  const SharedTextAction(this.text);

  final String text;
}

/// The phone side of the assistants:
/// - Siri (iPhone) adds tasks to an inbox while Taskwise may be closed, and
///   reads a snapshot of what's due ([AssistantInboxEntry],
///   [buildAssistantSnapshot]);
/// - Android's "New task" shortcut and share sheet arrive as
///   [AssistantAction]s.
///
/// Desktops and tests use [NoAssistantPlatform].
abstract class AssistantPlatform {
  /// Whether this device has an inbox and a snapshot (the iPhone).
  bool get hasInbox;

  /// The inbox's entries, oldest first. They stay there until [ackInbox].
  Future<List<AssistantInboxEntry>> readInbox();

  /// Removes the entries with these ids (they are in the database now).
  Future<void> ackInbox(List<String> ids);

  /// Replaces what the assistant can read out (see [buildAssistantSnapshot]).
  Future<void> setSnapshot(Map<String, Object?> snapshot);

  /// The action Taskwise was started with, once (null afterwards).
  Future<AssistantAction?> takeLaunchAction();

  /// Actions that arrive while Taskwise runs, and "the inbox changed" (Siri
  /// added a task while Taskwise was open) as null.
  Stream<AssistantAction?> get events;
}

class NoAssistantPlatform implements AssistantPlatform {
  @override
  bool get hasInbox => false;

  @override
  Future<List<AssistantInboxEntry>> readInbox() async => const [];

  @override
  Future<void> ackInbox(List<String> ids) async {}

  @override
  Future<void> setSnapshot(Map<String, Object?> snapshot) async {}

  @override
  Future<AssistantAction?> takeLaunchAction() async => null;

  @override
  Stream<AssistantAction?> get events => const Stream.empty();
}

/// Phones: the `taskwise/assistant` channel, served by `AssistantPlugin.swift`
/// on the iPhone and `TaskwiseAndroidPlugin.kt` on Android.
class NativeAssistantPlatform implements AssistantPlatform {
  NativeAssistantPlatform({required this.hasInbox}) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('taskwise/assistant');

  @override
  final bool hasInbox;

  final _events = StreamController<AssistantAction?>.broadcast();

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'inboxChanged':
        _events.add(null);
      case 'action':
        final action = _action(call.arguments);
        if (action != null) _events.add(action);
    }
    return null;
  }

  static AssistantAction? _action(Object? args) {
    if (args is! Map) return null;
    return switch (args['type']) {
      'newTask' => const NewTaskAction(),
      'share' when args['text'] is String => SharedTextAction(
        args['text'] as String,
      ),
      _ => null,
    };
  }

  @override
  Future<List<AssistantInboxEntry>> readInbox() async {
    if (!hasInbox) return const [];
    final json = await _channel.invokeMethod<String>('readInbox');
    if (json == null || json.isEmpty) return const [];
    try {
      return parseAssistantInbox(jsonDecode(json));
    } on FormatException catch (e) {
      appLog.warning('assistant', 'Unreadable inbox: $e');
      return const [];
    }
  }

  @override
  Future<void> ackInbox(List<String> ids) async {
    if (!hasInbox || ids.isEmpty) return;
    await _channel.invokeMethod('ackInbox', ids);
  }

  @override
  Future<void> setSnapshot(Map<String, Object?> snapshot) async {
    if (!hasInbox) return;
    await _channel.invokeMethod('setSnapshot', jsonEncode(snapshot));
  }

  @override
  Future<AssistantAction?> takeLaunchAction() async =>
      _action(await _channel.invokeMethod<Object?>('takeLaunchAction'));

  @override
  Stream<AssistantAction?> get events => _events.stream;
}
