import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:taskwise_shared/taskwise_shared.dart';

import '../logging/app_log.dart';
import '../state/providers.dart';
import '../version.dart';
import 'update_installer.dart';
import 'update_key.dart';
import 'update_verifier.dart';

/// How updates work on this device. The default (tests, until `main()`
/// overrides it) is off: no checks, no update rows in Settings.
final class UpdateConfig {
  const UpdateConfig({
    this.enabled = false,
    this.installer,
    this.isIos = false,
    this.releaseUrl = latestReleaseUrl,
  });

  /// Whether this device looks for updates at all.
  final bool enabled;

  /// Installs updates here; null when Taskwise can only point to them
  /// (iPhone, a build run from source, an unknown install).
  final UpdateInstaller? installer;

  /// The iPhone: updates go through iloader or SideStore.
  final bool isIos;

  /// GitHub's "latest release" API address.
  final String releaseUrl;
}

final updateConfigProvider = Provider<UpdateConfig>(
  (ref) => const UpdateConfig(),
);

final updateHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final updateVerifierProvider = Provider<UpdateVerifier>(
  (ref) => UpdateVerifier(),
);

/// The version this app is (overridable in tests).
final currentVersionProvider = Provider<AppVersion>(
  (ref) => AppVersion.tryParse(appVersion)!,
);

enum UpdatePhase {
  /// Not checked yet in this run.
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  failed,
}

enum UpdateError {
  /// Couldn't reach GitHub (offline, rate limit, server error).
  check,

  /// The download broke off.
  download,

  /// The files didn't pass the signature or hash check.
  verification,

  /// Installing failed.
  install,

  /// Android: allow installing apps from Taskwise first.
  needsPermission,
}

final class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.progress,
    this.error,
    this.autoCheck = true,
    this.checkedAt,
    this.dismissed = false,
  });

  final UpdatePhase phase;

  /// The newer release, once one was found.
  final ReleaseInfo? release;

  /// Download progress 0-1, or null when the size is unknown.
  final double? progress;
  final UpdateError? error;
  final bool autoCheck;
  final DateTime? checkedAt;

  /// "Later" was pressed: no banner for this release in this run.
  final bool dismissed;

  bool get busy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.installing;

  UpdateState copyWith({
    UpdatePhase? phase,
    ReleaseInfo? release,
    double? Function()? progress,
    UpdateError? Function()? error,
    bool? autoCheck,
    DateTime? checkedAt,
    bool? dismissed,
  }) => UpdateState(
    phase: phase ?? this.phase,
    release: release ?? this.release,
    progress: progress == null ? this.progress : progress(),
    error: error == null ? this.error : error(),
    autoCheck: autoCheck ?? this.autoCheck,
    checkedAt: checkedAt ?? this.checkedAt,
    dismissed: dismissed ?? this.dismissed,
  );
}

/// Looks for a newer Taskwise on GitHub Releases (at start and about once a
/// day while running, if allowed), and downloads, verifies and installs it
/// when asked. Watched by the app root; the banner and Settings → About
/// show its state.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

class UpdateController extends Notifier<UpdateState> {
  /// How often to check, at most.
  static const checkInterval = Duration(hours: 20);

  /// Wait a little after start, so the check doesn't slow the start down.
  static const startDelay = Duration(seconds: 15);

  Timer? _timer;

  /// Set once the user flips the switch, so the saved value (still
  /// loading) doesn't undo it.
  bool _autoCheckChanged = false;

  /// A downloaded and verified update file, kept for a retry.
  ({String name, File file, String hash})? _verified;

  UpdateConfig get _config => ref.read(updateConfigProvider);

  @override
  UpdateState build() {
    ref.onDispose(() => _timer?.cancel());
    if (ref.watch(updateConfigProvider).enabled) {
      unawaited(_loadSettings());
      _timer = Timer(startDelay, () {
        unawaited(_autoCheck());
        _timer = Timer.periodic(
          const Duration(hours: 1),
          (_) => unawaited(_autoCheck()),
        );
      });
    }
    return const UpdateState();
  }

  Future<void> _loadSettings() async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .getUpdateSettings();
    if (!ref.mounted) return;
    state = state.copyWith(
      autoCheck: _autoCheckChanged ? null : saved.autoCheck,
      checkedAt: saved.checkedAt,
    );
  }

  Future<void> _autoCheck() async {
    final saved = await ref
        .read(settingsRepositoryProvider)
        .getUpdateSettings();
    if (!ref.mounted || !saved.autoCheck || state.busy) return;
    final now = ref.read(clockProvider)();
    final last = saved.checkedAt;
    if (last != null && now.difference(last) < checkInterval) return;
    await check();
  }

  Future<void> setAutoCheck(bool value) async {
    _autoCheckChanged = true;
    state = state.copyWith(autoCheck: value);
    await ref.read(settingsRepositoryProvider).setUpdateAutoCheck(value);
  }

  /// Asks GitHub for the newest release.
  Future<void> check() async {
    if (!_config.enabled || state.busy) return;
    state = state.copyWith(phase: UpdatePhase.checking, error: () => null);
    try {
      final response = await ref
          .read(updateHttpClientProvider)
          .get(
            Uri.parse(_config.releaseUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 30));
      // 404: no published release yet.
      final release = response.statusCode == 404
          ? null
          : response.statusCode == 200
          ? ReleaseInfo.tryFromGitHub(jsonDecode(response.body))
          : throw HttpException('HTTP ${response.statusCode}');
      final now = ref.read(clockProvider)();
      await ref.read(settingsRepositoryProvider).setUpdateCheckedAt(now);
      if (!ref.mounted) return;
      final newer =
          release != null && release.version > ref.read(currentVersionProvider);
      state = UpdateState(
        phase: newer ? UpdatePhase.available : UpdatePhase.upToDate,
        release: newer ? release : null,
        autoCheck: state.autoCheck,
        checkedAt: now,
        dismissed:
            newer &&
            state.dismissed &&
            state.release?.version == release.version,
      );
      if (newer) {
        appLog.info('update', 'Taskwise ${release.version} is available');
      }
    } on Object catch (e) {
      appLog.warning('update', 'Update check failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: () => UpdateError.check,
      );
    }
  }

  /// Hides the banner for this release until Taskwise restarts.
  void dismiss() => state = state.copyWith(dismissed: true);

  /// Downloads, verifies and installs the available update. On desktop
  /// Taskwise then restarts as the new version.
  Future<void> install() async {
    final release = state.release;
    final installer = _config.installer;
    if (release == null || installer == null || state.busy) return;
    final asset = release.assetFor(installer.target);
    final sumsAsset = release.checksums;
    final sigAsset = release.signature;
    if (asset == null || sumsAsset == null || sigAsset == null) {
      appLog.warning('update', 'Release ${release.version} lacks files');
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: () => UpdateError.verification,
      );
      return;
    }
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: () => 0,
      error: () => null,
    );
    File? file;
    try {
      final kept = _verified;
      if (kept != null &&
          kept.name == asset.name &&
          await kept.file.exists() &&
          await _hashFile(kept.file) == kept.hash) {
        // Downloaded and verified before (Android asked for permission, or
        // the update screen was cancelled): no need to download again.
        file = kept.file;
      } else {
        _verified = null;
        file = await _downloadVerified(installer, asset, sumsAsset, sigAsset);
      }
    } on UpdateVerificationException catch (e) {
      appLog.warning('update', '$e');
      await _deleteQuietly(file);
      return _fail(UpdateError.verification);
    } on Object catch (e) {
      appLog.warning('update', 'Update download failed: $e');
      await _deleteQuietly(file);
      return _fail(UpdateError.download);
    }

    state = state.copyWith(phase: UpdatePhase.installing, progress: () => null);
    try {
      final outcome = await installer.install(file);
      if (!ref.mounted) return;
      switch (outcome) {
        case InstallOutcome.started:
          _verified = null;
          appLog.info('update', 'Installing Taskwise ${release.version}');
        case InstallOutcome.needsPermission:
          _fail(UpdateError.needsPermission);
        case InstallOutcome.cancelled:
          state = state.copyWith(phase: UpdatePhase.available);
      }
    } on Object catch (e, stack) {
      appLog.error('update', e, stack, 'Installing the update failed');
      _verified = null;
      await _deleteQuietly(file);
      _fail(UpdateError.install);
    }
  }

  /// Fetches and checks the signed SHA256SUMS, then downloads [asset] and
  /// checks its hash. Remembers the file for a retry.
  Future<File> _downloadVerified(
    UpdateInstaller installer,
    ReleaseAsset asset,
    ReleaseAsset sumsAsset,
    ReleaseAsset sigAsset,
  ) async {
    final client = ref.read(updateHttpClientProvider);
    final sums = await ref
        .read(updateVerifierProvider)
        .verifiedSums(
          await _bytes(client, sumsAsset.url),
          await _bytes(client, sigAsset.url),
        );
    final file = await installer.downloadFile(asset);
    try {
      final hash = await _download(client, asset, file);
      UpdateVerifier.checkHash(sums, asset.name, hash);
      _verified = (name: asset.name, file: file, hash: hash);
    } on Object {
      await _deleteQuietly(file);
      rethrow;
    }
    appLog.info('update', 'Downloaded and verified ${asset.name}');
    return file;
  }

  static Future<String> _hashFile(File file) async {
    final hash = Sha256Accumulator();
    await file.openRead().forEach(hash.add);
    return hash.close();
  }

  void _fail(UpdateError error) {
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: UpdatePhase.failed,
      error: () => error,
      progress: () => null,
    );
  }

  Future<List<int>> _bytes(http.Client client, String url) async {
    final response = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    return response.bodyBytes;
  }

  /// Streams [asset] into [file], reporting progress; returns its SHA-256.
  Future<String> _download(
    http.Client client,
    ReleaseAsset asset,
    File file,
  ) async {
    final response = await client
        .send(http.Request('GET', Uri.parse(asset.url)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for ${asset.name}');
    }
    final total = response.contentLength ?? asset.size;
    final hash = Sha256Accumulator();
    final sink = file.openWrite();
    var received = 0;
    var lastShown = 0.0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        sink.add(chunk);
        hash.add(chunk);
        received += chunk.length;
        if (total > 0 && ref.mounted) {
          final progress = received / total;
          if (progress - lastShown >= 0.01 || progress >= 1) {
            lastShown = progress;
            state = state.copyWith(progress: () => progress.clamp(0, 1));
          }
        }
      }
    } finally {
      await sink.close();
    }
    return hash.close();
  }

  static Future<void> _deleteQuietly(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // Left for the next update to overwrite.
    }
  }
}
