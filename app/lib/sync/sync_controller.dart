import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/db/app_database.dart';
import '../state/providers.dart';
import 'sync_api.dart';
import 'sync_engine.dart';
import 'token_store.dart';

/// Where the device token is kept. Tests override it with a
/// [MemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// The HTTP client for the sync server. Tests override it.
final syncHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// This device's type, sent when signing in. Overridden in `main()`.
final deviceTypeProvider = Provider<DeviceType>((ref) => DeviceType.other);

enum SyncPhase {
  /// Connected and up to date (or about to sync).
  idle,
  syncing,

  /// The server can't be reached; retried every minute.
  offline,

  /// The server refused this device's token (revoked, or the account was
  /// reset). Sync stops until the user signs in again.
  signedOut,

  /// Something else went wrong; retried every minute.
  error,
}

/// What the UI shows about sync.
final class SyncState {
  const SyncState({
    this.loaded = false,
    this.serverUrl,
    this.username,
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.message,
    this.bannerDismissed = false,
  });

  /// False until the saved account has been read at start-up.
  final bool loaded;

  /// The server this device is signed in to; null when not connected.
  final String? serverUrl;
  final String? username;
  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// Technical detail of the last error, if any.
  final String? message;

  /// The "connect your devices" banner was dismissed.
  final bool bannerDismissed;

  bool get connected => serverUrl != null;

  SyncState copyWith({
    bool? loaded,
    String? Function()? serverUrl,
    String? Function()? username,
    SyncPhase? phase,
    DateTime? Function()? lastSyncedAt,
    String? Function()? message,
    bool? bannerDismissed,
  }) => SyncState(
    loaded: loaded ?? this.loaded,
    serverUrl: serverUrl != null ? serverUrl() : this.serverUrl,
    username: username != null ? username() : this.username,
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
    message: message != null ? message() : this.message,
    bannerDismissed: bannerDismissed ?? this.bannerDismissed,
  );
}

/// Runs sync for the app: signs in and out, and syncs at start, when the
/// app comes back to the foreground, a moment after each local change,
/// every minute, and on "Sync now" (SPEC.md section 4). Watch it once (the
/// app root does) to start it.
final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  static const _interval = Duration(minutes: 1);
  static const _debounce = Duration(seconds: 2);

  SyncEngine? _engine;
  Timer? _periodic;
  Timer? _pending;
  StreamSubscription<int>? _outbox;
  AppLifecycleListener? _lifecycle;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  @override
  SyncState build() {
    ref.onDispose(_stop);
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const SyncState();
  }

  Future<void> _load() async {
    final saved = await ref.read(settingsRepositoryProvider).getSyncSettings();
    final token = saved.serverUrl == null
        ? null
        : await ref.read(tokenStoreProvider).read();
    if (_disposed) return;
    state = state.copyWith(
      loaded: true,
      serverUrl: () => saved.serverUrl,
      username: () => saved.username,
      lastSyncedAt: () => saved.lastSyncedAt,
      bannerDismissed: saved.bannerDismissed,
      phase: saved.serverUrl != null && token == null
          ? SyncPhase.signedOut
          : SyncPhase.idle,
    );
    if (saved.serverUrl case final url? when token != null) _start(url, token);
  }

  // ------------------------------------------------------------- account

  /// Checks the server, optionally creates the account (with the server's
  /// setup secret), signs this device in and starts syncing. Throws
  /// [SyncApiException] or [FormatException] (bad address) for the sign-in
  /// screen to explain.
  Future<void> signIn({
    required String serverUrl,
    required String username,
    required String password,
    required String deviceName,
    String? setupSecret,
  }) async {
    final api = SyncApi(
      baseUrl: serverUrl,
      client: ref.read(syncHttpClientProvider),
    );
    await api.health();
    if (setupSecret != null) {
      await api.setup(
        setupSecret: setupSecret,
        username: username,
        password: password,
      );
    }
    final deviceId = ref.read(deviceIdProvider);
    final login = await api.login(
      username: username,
      password: password,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: ref.read(deviceTypeProvider),
    );
    _stop();
    await ref.read(tokenStoreProvider).write(login.token);
    final url = api.baseUri.toString();
    await ref
        .read(settingsRepositoryProvider)
        .setSyncAccount(serverUrl: url, username: username);
    final db = ref.read(databaseProvider);
    await (db.update(db.devices)..where((d) => d.id.equals(deviceId))).write(
      DevicesCompanion(name: Value(login.device.name)),
    );
    // The server may not have this device's data yet (first connect, or a
    // different server): offer all of it; what it has comes back stale.
    await db.queueAllForSync();
    state = state.copyWith(
      serverUrl: () => url,
      username: () => username,
      phase: SyncPhase.idle,
      message: () => null,
      lastSyncedAt: () => null,
    );
    _start(url, login.token);
  }

  /// Revokes this device on the server (if it can be reached) and stops
  /// syncing. Local data stays.
  Future<void> signOut() async {
    final engine = _engine;
    _stop();
    if (engine != null) {
      try {
        await engine.api.revokeDevice(ref.read(deviceIdProvider));
      } on SyncApiException {
        // Offline or already revoked: forgetting the token is enough.
      }
    }
    await ref.read(tokenStoreProvider).delete();
    await ref.read(settingsRepositoryProvider).setSyncAccount();
    state = state.copyWith(
      serverUrl: () => null,
      username: () => null,
      phase: SyncPhase.idle,
      message: () => null,
      lastSyncedAt: () => null,
    );
  }

  Future<void> dismissBanner() async {
    state = state.copyWith(bannerDismissed: true);
    await ref.read(settingsRepositoryProvider).setSyncBannerDismissed();
  }

  // ------------------------------------------------------------- devices

  Future<void> renameDevice(String id, String name) async {
    final engine = _requireEngine();
    await engine.api.renameDevice(id, name);
    await engine.refreshDevices();
  }

  /// Revokes another device; it has to sign in again to sync.
  Future<void> removeDevice(String id) async {
    final engine = _requireEngine();
    await engine.api.revokeDevice(id);
    await engine.refreshDevices();
  }

  /// Hands the main role to another device (from the main device).
  Future<void> makeMain(String id) async {
    final engine = _requireEngine();
    await engine.api.makeMain(id);
    await engine.refreshDevices();
  }

  /// Makes this device the main one; [password] is the account password.
  /// Throws [SyncHttpException] with code `wrong_password` if it's wrong.
  Future<void> claimMain(String password) async {
    final engine = _requireEngine();
    await engine.api.claimMain(password);
    await engine.refreshDevices();
  }

  SyncEngine _requireEngine() =>
      _engine ??
      (throw const SyncHttpException(401, 'unauthorized', 'Not signed in'));

  // ---------------------------------------------------------------- sync

  /// Syncs now (or right after the sync already running).
  Future<void> syncNow() {
    if (_engine == null) return Future.value();
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _runLoop().whenComplete(() => _running = null);
  }

  Future<void> _runLoop() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again && _engine != null && !_disposed);
  }

  Future<void> _syncOnce() async {
    final engine = _engine;
    if (engine == null || _disposed) return;
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      await engine.sync();
      if (_disposed || _engine != engine) return;
      final now = ref.read(clockProvider)().toUtc();
      await ref.read(settingsRepositoryProvider).setLastSyncedAt(now);
      state = state.copyWith(
        phase: SyncPhase.idle,
        lastSyncedAt: () => now,
        message: () => null,
      );
    } on SyncNetworkException catch (e) {
      _fail(engine, SyncPhase.offline, e.message);
    } on SyncHttpException catch (e) {
      if (e.status == 401) {
        _stop();
        await ref.read(tokenStoreProvider).delete();
        _fail(engine, SyncPhase.signedOut, e.message, stopped: true);
      } else if (e.status == 429 || e.status >= 500) {
        _fail(engine, SyncPhase.offline, e.message);
      } else {
        _fail(engine, SyncPhase.error, '${e.code}: ${e.message}');
      }
    } on Object catch (e) {
      // A bug or an unexpected reply: show it, retry on the next tick.
      _fail(engine, SyncPhase.error, '$e');
    }
  }

  void _fail(
    SyncEngine engine,
    SyncPhase phase,
    String message, {
    bool stopped = false,
  }) {
    if (_disposed || (!stopped && _engine != engine)) return;
    state = state.copyWith(phase: phase, message: () => message);
  }

  void _start(String serverUrl, String token) {
    final db = ref.read(databaseProvider);
    _engine = SyncEngine(
      db: db,
      api: SyncApi(
        baseUrl: serverUrl,
        token: token,
        client: ref.read(syncHttpClientProvider),
      ),
      deviceId: ref.read(deviceIdProvider),
    );
    _periodic = Timer.periodic(_interval, (_) => unawaited(syncNow()));
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(syncNow()));
    // A moment after local changes are queued (pulls leave the queue
    // empty, so they don't trigger this).
    final count = db.syncOutbox.recordId.count();
    _outbox = (db.selectOnly(db.syncOutbox)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .watchSingle()
        .listen((queued) {
          if (queued == 0) return;
          _pending?.cancel();
          _pending = Timer(_debounce, () => unawaited(syncNow()));
        });
    unawaited(syncNow());
  }

  void _stop() {
    _engine = null;
    _periodic?.cancel();
    _pending?.cancel();
    unawaited(_outbox?.cancel());
    _outbox = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
