import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

Map<String, Object?> release({
  String tag = 'v1.2.0',
  bool draft = false,
  bool prerelease = false,
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/Krkr8/taskwise/releases/tag/$tag',
  'body': '### Added\n\n- **Siri** on the iPhone ([guide](https://x)).\n',
  'assets': [
    for (final name in [
      'taskwise-1.2.0-windows-x64.zip',
      'taskwise-1.2.0-linux-x86_64.AppImage',
      'taskwise-1.2.0-linux-x64.tar.gz',
      'taskwise-1.2.0-android.apk',
      'taskwise-1.2.0-ios-unsigned.ipa',
      'SHA256SUMS',
      'SHA256SUMS.sig',
      'sidestore-source.json',
    ])
      {
        'name': name,
        'size': 1000,
        'browser_download_url':
            'https://github.com/Krkr8/taskwise/releases/download/$tag/$name',
      },
    {'name': 'broken'},
  ],
};

void main() {
  group('AppVersion', () {
    test('parses tags and pubspec versions', () {
      expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
      expect(AppVersion.tryParse('1.1.0+13').toString(), '1.1.0');
      expect(AppVersion.tryParse('2.0.0-beta.1')?.preRelease, 'beta.1');
      for (final bad in [null, '', '1.2', 'v1.2.3.4', 'latest', '1.x.0']) {
        expect(AppVersion.tryParse(bad), isNull, reason: bad);
      }
    });

    test('orders versions like semver', () {
      final ordered = [
        '0.9.9',
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0',
        '1.0.1',
        '1.2.0',
        '1.10.0',
        '2.0.0',
      ].map((v) => AppVersion.tryParse(v)!).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i] > ordered[i - 1], isTrue, reason: '${ordered[i]}');
      }
      expect(AppVersion.tryParse('v1.0.0'), AppVersion.tryParse('1.0.0+5'));
    });
  });

  group('ReleaseInfo', () {
    test('reads a published release and finds each platform\'s file', () {
      final info = ReleaseInfo.tryFromGitHub(release())!;
      expect(info.version.toString(), '1.2.0');
      expect(info.pageUrl, endsWith('/tag/v1.2.0'));
      expect(info.assets, hasLength(8));
      expect(
        info.assetFor(UpdateTarget.windows)?.name,
        'taskwise-1.2.0-windows-x64.zip',
      );
      expect(
        info.assetFor(UpdateTarget.linuxAppImage)?.name,
        'taskwise-1.2.0-linux-x86_64.AppImage',
      );
      expect(
        info.assetFor(UpdateTarget.linuxTarball)?.name,
        'taskwise-1.2.0-linux-x64.tar.gz',
      );
      expect(info.assetFor(UpdateTarget.android)?.size, 1000);
      expect(info.assetFor(UpdateTarget.ios), isNotNull);
      expect(info.checksums?.name, 'SHA256SUMS');
      expect(info.signature?.url, endsWith('/SHA256SUMS.sig'));
    });

    test('ignores drafts, pre-releases and odd tags', () {
      expect(ReleaseInfo.tryFromGitHub(release(draft: true)), isNull);
      expect(ReleaseInfo.tryFromGitHub(release(prerelease: true)), isNull);
      expect(ReleaseInfo.tryFromGitHub(release(tag: 'nightly')), isNull);
      expect(ReleaseInfo.tryFromGitHub('not json'), isNull);
    });

    test('a release without a platform\'s file has no update for it', () {
      final json = release()
        ..['assets'] = [
          {'name': 'taskwise-1.2.0-android.apk', 'browser_download_url': 'u'},
        ];
      final info = ReleaseInfo.tryFromGitHub(json)!;
      expect(info.assetFor(UpdateTarget.windows), isNull);
      expect(info.checksums, isNull);
    });
  });

  test('parseSha256Sums reads sha256sum output', () {
    final a = 'a' * 64;
    final b = 'B' * 64;
    final sums = parseSha256Sums(
      '$a  taskwise-1.2.0-android.apk\n'
      '$b *dist/taskwise-1.2.0-windows-x64.zip\n'
      'garbage\n\n',
    );
    expect(sums, {
      'taskwise-1.2.0-android.apk': a,
      'taskwise-1.2.0-windows-x64.zip': 'b' * 64,
    });
  });

  test('plainReleaseNotes drops markdown and shortens', () {
    expect(
      plainReleaseNotes(
        '### Added\n\n- **Siri** on the iPhone ([guide](https://x)).\n',
      ),
      'Added\n• Siri on the iPhone (guide).',
    );
    final long = List.generate(20, (i) => '- line $i').join('\n');
    final short = plainReleaseNotes(long, maxLines: 3);
    expect(short.split('\n'), ['• line 0', '• line 1', '• line 2', '…']);
  });
}
