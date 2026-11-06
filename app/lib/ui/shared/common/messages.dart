import 'package:flutter/material.dart';

import '../../../logging/app_log.dart';
import '../tasks/labels.dart';

/// A short message at the bottom of the screen.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Runs a user action. If it fails unexpectedly, the error goes to the log
/// (under [tag]) and the user sees a short, translated message instead of
/// the raw error. Returns null on failure.
Future<T?> guardAction<T>(
  BuildContext context,
  String tag,
  Future<T> Function() action,
) async {
  final failed = context.l10n.actionFailed;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    return await action();
  } on Object catch (e, stack) {
    appLog.error(tag, e, stack);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
}
