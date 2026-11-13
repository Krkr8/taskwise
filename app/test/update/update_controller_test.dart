import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/update/update_controller.dart';
import 'package:taskwise/update/update_installer.dart';
import 'package:taskwise/update/update_verifier.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import 'fake_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeRelease release;
  late Directory dir;
  late FakeInstaller installer;
  late ProviderContainer container;
  final now = DateTime.utc(2026, 11, 12, 9);

  ProviderContainer make({
    String current = '1.1.0',
    UpdateInstaller? installerOverride,
    bool useInstaller = true,
  }) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('pc'),
      clockProvider.overrideWithValue(() => now),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      currentVersionProvider.overrideWithValue(AppVersion.tryParse(current)!),
      updateConfigProvider.overrideWithValue(
        UpdateConfig(
          enabled: true,
          installer: useInstaller ? (installerOverride ?? installer) : null,
          releaseUrl: '${FakeRelease.base}/latest',
        ),
      ),
      updateHttpClientProvider.overrideWithValue(release.client()),
      updateVerifierProvider.overrideWithValue(
        UpdateVerifier(publicKey: release.publicKey),
      ),
    ],
  );

  setUp(() async {
    db = openTestDatabase();
    release = await FakeRelease.create();
    dir = await Directory.systemTemp.createTemp('taskwise-update-test');
    installer = FakeInstaller(dir);
    container = make();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  UpdateController controller() {
    container.listen(updateControllerProvider, (_, _) {});
    return container.read(updateControllerProvider.notifier);
  }

  UpdateState state() => container.read(updateControllerProvider);

  group('check', () {
    test('finds a newer release and remembers when it checked', () async {
      await controller().check();
      expect(state().phase, UpdatePhase.available);
      expect(state().release?.version.toString(), '1.2.0');
      expect(state().checkedAt, now);
      final saved = await SettingsRepository(
        db,
        deviceId: 'pc',
      ).getUpdateSettings();
      expect(saved.checkedAt, now);
      expect(saved.autoCheck, isTrue);
    });

    test('the same or an older version is up to date', () async {
      for (final current in ['1.2.0', '1.3.0']) {
        container.dispose();
        container = make(current: current);
        await controller().check();
        expect(state().phase, UpdatePhase.upToDate, reason: current);
        expect(state().release, isNull);
      }
    });

    test('no published release yet (404) is up to date', () async {
      release.statusCode = 404;
      await controller().check();
      expect(state().phase, UpdatePhase.upToDate);
    });

    test('a draft is ignored', () async {
      release.draft = true;
      await controller().check();
      expect(state().phase, UpdatePhase.upToDate);
    });

    test('a server error is reported', () async {
      release.statusCode = 503;
      await controller().check();
      expect(state().phase, UpdatePhase.failed);
      expect(state().error, UpdateError.check);
    });

    test('Later hides the release until a newer one comes', () async {
      final c = controller();
      await c.check();
      c.dismiss();
      await c.check();
      expect(state().dismissed, isTrue);
    });

    test('the automatic check can be turned off', () async {
      await controller().setAutoCheck(false);
      expect(state().autoCheck, isFalse);
      final saved = await SettingsRepository(
        db,
        deviceId: 'pc',
      ).getUpdateSettings();
      expect(saved.autoCheck, isFalse);
    });
  });

  group('install', () {
    test('downloads, verifies and installs the platform\'s file', () async {
      final c = controller();
      await c.check();
      await c.install();
      expect(utf8.decode(installer.installed!), 'apk 1.2.0');
      expect(state().phase, UpdatePhase.installing);
      expect(
        release.requests,
        containsAll([
          '/download/SHA256SUMS',
          '/download/SHA256SUMS.sig',
          '/download/${release.androidName}',
        ]),
      );
    });

    test('a bad signature installs nothing', () async {
      release.tamperSignature = true;
      final c = controller();
      await c.check();
      await c.install();
      expect(installer.installed, isNull);
      expect(state().error, UpdateError.verification);
      // The file isn't even downloaded.
      expect(
        release.requests,
        isNot(contains('/download/${release.androidName}')),
      );
    });

    test('a changed file installs nothing and is deleted', () async {
      release.tamperFile = true;
      final c = controller();
      await c.check();
      await c.install();
      expect(installer.installed, isNull);
      expect(state().error, UpdateError.verification);
      expect(File('${dir.path}/download').existsSync(), isFalse);
    });

    test('a release without this platform\'s file installs nothing', () async {
      container.dispose();
      container = make(
        installerOverride: FakeInstaller(dir, target: UpdateTarget.windows),
      );
      final c = controller();
      await c.check();
      await c.install();
      expect(state().error, UpdateError.verification);
    });

    test('Android: permission first, then Cancel goes back', () async {
      final c = controller();
      await c.check();
      installer.outcome = InstallOutcome.needsPermission;
      await c.install();
      expect(state().error, UpdateError.needsPermission);
      installer.outcome = InstallOutcome.cancelled;
      await c.install();
      expect(state().phase, UpdatePhase.available);
      // The verified file was kept: the retries didn't download again.
      final apkPath = '/download/${release.androidName}';
      expect(release.requests.where((r) => r == apkPath), hasLength(1));
      installer.outcome = InstallOutcome.started;
      await c.install();
      expect(utf8.decode(installer.installed!), 'apk 1.2.0');
      expect(release.requests.where((r) => r == apkPath), hasLength(1));
    });

    test('an install error is reported', () async {
      installer.throwOnInstall = const FileSystemException('read-only');
      final c = controller();
      await c.check();
      await c.install();
      expect(state().error, UpdateError.install);
    });

    test('without an installer (iPhone) nothing is downloaded', () async {
      container.dispose();
      container = make(useInstaller: false);
      final c = controller();
      await c.check();
      await c.install();
      expect(state().phase, UpdatePhase.available);
      expect(release.requests, ['/latest']);
    });
  });

  test('the built-in key is a valid Ed25519 public key', () {
    expect(() => UpdateVerifier(), returnsNormally);
  });
}
