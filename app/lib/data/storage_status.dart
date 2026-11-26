import 'package:drift_flutter/drift_flutter.dart'
    show WasmStorageImplementation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device keeps its database between starts.
enum StorageStatus {
  /// A file on the computer or phone, or the browser's own storage.
  persistent,

  /// The browser offered no storage, so the tasks only live in memory and
  /// are gone after a reload (unless they are synced).
  temporary,
}

/// What the browser's database ([WasmStorageImplementation]) means for the
/// user: only the in-memory fallback loses the tasks.
StorageStatus storageStatusFor(WasmStorageImplementation storage) =>
    storage == WasmStorageImplementation.inMemory
    ? StorageStatus.temporary
    : StorageStatus.persistent;

/// This start's [StorageStatus]. Overridden in `main()` (`AppBootstrap`).
final storageStatusProvider = Provider<StorageStatus>(
  (ref) => StorageStatus.persistent,
);
