# taskwise_android

Taskwise's native Android code, as a local Flutter plugin (Android only):

- **Location reminders** (`LocationReminderManager.kt`, `GeofenceEngine.kt`): the Android twin of the iPhone's Swift code in `app/ios/Runner/`. `GeofenceEngine.kt` is a line-by-line port of `GeofenceDecider.swift`; keep the two in step.
- **Saving files** (`FilesPlugin.kt`): the system "Save to" screen for backups and logs.

It is a plugin rather than code in `MainActivity`, so Flutter also registers it in the background engine that workmanager starts for background sync.

Tests (JVM, no device needed), from `app/android`:

```bash
./gradlew :taskwise_android:testDebugUnitTest
```

`GeofenceWalkTest` is the walk simulator from `tools/geofence_sim`, ported to Kotlin.
