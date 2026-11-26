import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../platform/app_target.dart';

/// Saves [text] as a file named [name] the way each platform expects, and
/// returns the message to show, or null when the user cancelled.
///
/// - Desktop: a save dialog (file_selector).
/// - iPhone: the app's Documents folder, which the Files app shows under
///   "On My iPhone → Taskwise".
/// - Android: the system's "Save to" screen (`ACTION_CREATE_DOCUMENT`, see
///   FilesPlugin.kt), since file_selector can't save there.
Future<String?> saveTextFile(
  AppLocalizations l10n, {
  required String name,
  required String text,
  required String mimeType,
  List<XTypeGroup> typeGroups = const [],
}) async {
  if (appTarget == AppTarget.android) {
    final saved = await _files.invokeMethod<bool>('saveFile', {
      'name': name,
      'mimeType': mimeType,
      'bytes': Uint8List.fromList(utf8.encode(text)),
    });
    return saved == true ? l10n.fileSaved(name) : null;
  }
  final String path;
  if (appTarget == AppTarget.ios) {
    path = '${(await getApplicationDocumentsDirectory()).path}/$name';
  } else {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: typeGroups,
    );
    if (location == null) return null;
    path = location.path;
  }
  await File(path).writeAsString(text, flush: true);
  return appTarget == AppTarget.ios
      ? l10n.backupSavedIos(name)
      : l10n.backupSaved(path);
}

const _files = MethodChannel('taskwise/files');
