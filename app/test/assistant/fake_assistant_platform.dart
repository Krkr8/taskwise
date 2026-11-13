import 'dart:async';

import 'package:taskwise/assistant/assistant_platform.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Siri's side, in memory.
class FakeAssistantPlatform implements AssistantPlatform {
  FakeAssistantPlatform({this.hasInbox = true});

  @override
  final bool hasInbox;

  final inbox = <AssistantInboxEntry>[];
  Map<String, Object?>? snapshot;
  int snapshotWrites = 0;
  final events$ = StreamController<AssistantAction?>.broadcast();

  /// What [takeLaunchAction] returns once.
  AssistantAction? launchAction;

  @override
  Future<List<AssistantInboxEntry>> readInbox() async => List.of(inbox);

  @override
  Future<void> ackInbox(List<String> ids) async =>
      inbox.removeWhere((e) => ids.contains(e.id));

  @override
  Future<void> setSnapshot(Map<String, Object?> value) async {
    snapshot = value;
    snapshotWrites++;
  }

  @override
  Future<AssistantAction?> takeLaunchAction() async {
    final action = launchAction;
    launchAction = null;
    return action;
  }

  @override
  Stream<AssistantAction?> get events => events$.stream;
}
