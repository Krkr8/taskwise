import 'package:flutter/material.dart';

import '../tasks/labels.dart';

/// Asks for a single line of text. Returns the trimmed text, or null if the
/// dialog was cancelled or left blank.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String? confirmLabel,
}) async {
  final controller = TextEditingController(text: initialValue);
  final l10n = context.l10n;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(confirmLabel ?? l10n.save),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
