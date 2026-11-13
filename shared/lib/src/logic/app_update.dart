/// Finding Taskwise updates on GitHub Releases (M12). The app downloads,
/// verifies and installs them (app/lib/update/); this part is pure logic.
library;

/// A version like `1.2.3` or `1.2.3-beta.1` (Semantic Versioning, without
/// build metadata ordering).
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.preRelease]);

  /// Reads `1.2.3`, `v1.2.3`, `1.2.3-beta.1` or `1.2.3+13`; null otherwise.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4],
    );
  }

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  final int major;
  final int minor;
  final int patch;

  /// `beta.1` in `1.2.3-beta.1`; null for a normal release.
  final String? preRelease;

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    return _comparePre(preRelease, other.preRelease);
  }

  /// A pre-release sorts before its release; identifiers compare
  /// numerically when both are numbers (semver §11).
  static int _comparePre(String? a, String? b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final pa = a.split('.');
    final pb = b.split('.');
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = switch ((na, nb)) {
        (final int x, final int y) => x.compareTo(y),
        (int(), null) => -1,
        (null, int()) => 1,
        _ => pa[i].compareTo(pb[i]),
      };
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease == null ? '' : '-$preRelease'}';
}

/// How this copy of Taskwise was installed, which decides the file an
/// update needs.
enum UpdateTarget {
  /// The portable folder from `taskwise-<v>-windows-x64.zip`.
  windows('-windows-x64.zip'),

  /// `taskwise-<v>-linux-x86_64.AppImage`.
  linuxAppImage('-linux-x86_64.AppImage'),

  /// The folder `install.sh` made from `taskwise-<v>-linux-x64.tar.gz`.
  linuxTarball('-linux-x64.tar.gz'),

  /// `taskwise-<v>-android.apk`.
  android('-android.apk'),

  /// `taskwise-<v>-ios-unsigned.ipa`. The iPhone can't install it itself.
  ios('-ios-unsigned.ipa');

  const UpdateTarget(this.suffix);

  /// The end of the release file's name.
  final String suffix;
}

/// One file of a release.
final class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.size = 0});

  final String name;

  /// The download address (`browser_download_url`).
  final String url;
  final int size;
}

/// A published Taskwise release, from GitHub's
/// `GET /repos/{owner}/{repo}/releases/latest`.
final class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.assets,
  });

  /// Reads GitHub's release JSON. Returns null for drafts, pre-releases and
  /// anything without a readable version.
  static ReleaseInfo? tryFromGitHub(Object? json) {
    if (json is! Map) return null;
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final version = AppVersion.tryParse(json['tag_name'] as String?);
    if (version == null) return null;
    return ReleaseInfo(
      version: version,
      notes: (json['body'] as String? ?? '').trim(),
      pageUrl: json['html_url'] as String? ?? '',
      assets: [
        for (final a in (json['assets'] as List<Object?>? ?? const []))
          if (a case {
            'name': final String name,
            'browser_download_url': final String url,
          })
            ReleaseAsset(
              name: name,
              url: url,
              size: (a['size'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  final AppVersion version;

  /// The release text (this version's CHANGELOG section, markdown).
  final String notes;

  /// The release's page on GitHub.
  final String pageUrl;
  final List<ReleaseAsset> assets;

  /// The file [target] installs, if the release has one.
  ReleaseAsset? assetFor(UpdateTarget target) =>
      _named((n) => n.startsWith('taskwise-') && n.endsWith(target.suffix));

  /// `SHA256SUMS`: the SHA-256 of every release file.
  ReleaseAsset? get checksums => _named((n) => n == checksumsFileName);

  /// `SHA256SUMS.sig`: the Ed25519 signature of [checksums].
  ReleaseAsset? get signature => _named((n) => n == signatureFileName);

  ReleaseAsset? _named(bool Function(String) test) {
    for (final a in assets) {
      if (test(a.name)) return a;
    }
    return null;
  }
}

const checksumsFileName = 'SHA256SUMS';
const signatureFileName = 'SHA256SUMS.sig';

/// Reads `sha256sum` output: `<64 hex>  <file name>` per line (a `*` before
/// the name marks binary mode). Returns lower-case hashes by file name.
Map<String, String> parseSha256Sums(String text) {
  final sums = <String, String>{};
  for (final line in text.split('\n')) {
    final match = _sumLine.firstMatch(line.trim());
    if (match == null) continue;
    final name = match[2]!.split('/').last;
    sums[name] = match[1]!.toLowerCase();
  }
  return sums;
}

final _sumLine = RegExp(r'^([0-9a-fA-F]{64}) [ *](.+)$');

/// The release notes for the update dialog: markdown headings and emphasis
/// removed, at most [maxLines] non-empty lines.
String plainReleaseNotes(String markdown, {int maxLines = 12}) {
  final lines = <String>[];
  for (var line in markdown.split('\n')) {
    line = line
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!)
        .replaceFirstMapped(RegExp(r'^(\s*)[-*] '), (m) => '${m[1]}• ')
        .trimRight();
    if (line.trim().isEmpty) continue;
    lines.add(line);
  }
  if (lines.length <= maxLines) return lines.join('\n');
  return '${lines.take(maxLines).join('\n')}\n…';
}
