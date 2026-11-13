import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskwise/update/update_installer.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// A signed fake GitHub release with one file per platform.
class FakeRelease {
  FakeRelease._(this.keyPair, this.publicKey);

  static Future<FakeRelease> create({String version = '1.2.0'}) async {
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = (await keyPair.extractPublicKey()).bytes;
    return FakeRelease._(keyPair, publicKey).._version = version;
  }

  final SimpleKeyPair keyPair;
  final List<int> publicKey;
  late String _version;

  String get version => _version;
  String get tag => 'v$_version';
  String get androidName => 'taskwise-$_version-android.apk';
  static const base = 'https://example.test';

  /// File contents by name.
  late final Map<String, List<int>> files = {
    androidName: utf8.encode('apk $_version'),
    'taskwise-$_version-linux-x86_64.AppImage': utf8.encode('appimage'),
    'taskwise-$_version-ios-unsigned.ipa': utf8.encode('ipa'),
  };

  bool draft = false;
  int statusCode = 200;
  bool tamperSignature = false;
  bool tamperFile = false;

  Future<List<int>> sums() async {
    final lines = [
      for (final MapEntry(:key, :value) in files.entries)
        '${await _sha256(value)}  $key',
    ];
    return utf8.encode('${lines.join('\n')}\n');
  }

  static Future<String> _sha256(List<int> bytes) async => [
    for (final b in (await Sha256().hash(bytes)).bytes)
      b.toRadixString(16).padLeft(2, '0'),
  ].join();

  Map<String, Object?> releaseJson() => {
    'tag_name': tag,
    'draft': draft,
    'prerelease': false,
    'html_url': '$base/releases/$tag',
    'body': '### Added\n\n- **Updates** inside the app.\n',
    'assets': [
      for (final name in [...files.keys, 'SHA256SUMS', 'SHA256SUMS.sig'])
        {
          'name': name,
          'size': files[name]?.length ?? 0,
          'browser_download_url': '$base/download/$name',
        },
    ],
  };

  /// Every request the client got, by path.
  final requests = <String>[];

  http.Client client() => MockClient((request) async {
    final path = request.url.path;
    requests.add(path);
    if (path == '/latest') {
      if (statusCode != 200) return http.Response('nope', statusCode);
      return http.Response(jsonEncode(releaseJson()), 200);
    }
    final name = path.split('/').last;
    if (name == 'SHA256SUMS') return http.Response.bytes(await sums(), 200);
    if (name == 'SHA256SUMS.sig') {
      final signature = await Ed25519().sign(await sums(), keyPair: keyPair);
      final bytes = [...signature.bytes];
      if (tamperSignature) bytes[0] ^= 1;
      return http.Response.bytes(bytes, 200);
    }
    final file = files[name];
    if (file == null) return http.Response('missing', 404);
    return http.Response.bytes(
      tamperFile ? [...file, 0] : file,
      200,
      headers: {'content-length': '${file.length + (tamperFile ? 1 : 0)}'},
    );
  });
}

/// Records what it was asked to install.
class FakeInstaller implements UpdateInstaller {
  FakeInstaller(this.dir, {this.target = UpdateTarget.android});

  final Directory dir;
  @override
  final UpdateTarget target;

  InstallOutcome outcome = InstallOutcome.started;
  Object? throwOnInstall;
  List<int>? installed;

  @override
  Future<File> downloadFile(ReleaseAsset asset) async =>
      File('${dir.path}/download');

  @override
  Future<InstallOutcome> install(File file) async {
    if (throwOnInstall case final Object e) throw e;
    installed = await file.readAsBytes();
    return outcome;
  }
}
