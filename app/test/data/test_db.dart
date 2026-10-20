import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:taskwise/data/db/app_database.dart';

/// A fresh in-memory database for one test.
AppDatabase openTestDatabase() {
  // Streams from different tests never share a database, so this is safe.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// A clock tests can move forward by hand.
class FakeClock {
  FakeClock([DateTime? start])
    : current = start ?? DateTime.utc(2026, 10, 20, 9);

  DateTime current;

  DateTime call() => current;

  void advance([Duration by = const Duration(minutes: 1)]) =>
      current = current.add(by);
}
