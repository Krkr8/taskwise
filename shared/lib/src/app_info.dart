/// Static facts about Taskwise that both the app and server report.
abstract final class AppInfo {
  /// Human-readable product name.
  static const String name = 'Taskwise';

  /// Version of the sync API the server exposes and clients expect.
  static const int apiVersion = 1;

  /// Where the source lives (also the contact in [userAgent]).
  static const String repositoryUrl = 'https://github.com/Krkr8/taskwise';

  /// User-Agent for third-party services such as map search, which ask
  /// clients to identify themselves.
  static const String userAgent = '$name (+$repositoryUrl)';

  /// Base path for every versioned API route, e.g. `/api/v1`.
  static String get apiBasePath => '/api/v$apiVersion';
}
