/// Static facts about Taskwise that both the app and server report.
abstract final class AppInfo {
  /// Human-readable product name.
  static const String name = 'Taskwise';

  /// Version of the sync API the server exposes and clients expect.
  static const int apiVersion = 1;

  /// Base path for every versioned API route, e.g. `/api/v1`.
  static String get apiBasePath => '/api/v$apiVersion';
}
