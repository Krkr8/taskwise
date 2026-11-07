# Contributing to Taskwise

Thank you for wanting to help. Taskwise is a personal project, so small, focused changes are easiest to review. For a big change, open an issue first so we can talk about it.

## Set up

Follow [docs/dev-setup-fedora.md](docs/dev-setup-fedora.md). It installs Flutter 3.47.7, Node.js 24 and the Linux build tools. Other Linux distributions work too if you install the same things. Then:

```bash
git clone https://github.com/Krkr8/taskwise.git
cd taskwise
flutter pub get          # fetches the app and shared packages in one go
cd app && flutter run -d linux
```

Run `flutter` commands that build or run the app from `app/`, not from the repository root.

## How the code is organised

Read [docs/architecture.md](docs/architecture.md). In short:

- `app/` is the Flutter app, `shared/` is pure Dart logic (repeats, reminders, grouping), `server/` is the sync server.
- Putting something in `shared/` is better than putting it in `app/` when it has no Flutter code in it, because the tests are faster.
- The sync API is written down once in [docs/sync-api.md](docs/sync-api.md). The JSON fixtures in `shared/test/fixtures/` are tested by both the Dart and the TypeScript side. If you change the API, change the document and the fixtures too.

## Two rules for screens

1. **The app has four designs** (Classic, Lapis, Slate & Indigo, Brutal), each with its own screens in `app/lib/ui/designs/<name>/`. A change to a screen usually has to be made in **each design's copy**. Find all copies first: `find app/lib/ui -name task_detail.dart`.
2. **A new screen goes in `app/lib/ui/shared/`**, so it is built once for every design. It takes its colours, fonts and shapes from the current theme. Give a design its own copy only when it really needs one.

Every new text goes in **both** `app/lib/l10n/app_en.arb` and `app/lib/l10n/app_ar.arb`, then run `flutter gen-l10n` in `app/`. Check that new screens look right right-to-left (switch to Arabic in Settings). If you can't write Arabic, add your best attempt and say so in the pull request, and someone will check it.

## Generated code

Generated files are committed, and CI fails if they are out of date. After a change, run these in `app/`:

| You changed | Run |
|---|---|
| Database tables (`app/lib/data/db/`) | `dart run build_runner build --delete-conflicting-outputs` |
| UI text (`app/lib/l10n/*.arb`) | `flutter gen-l10n` |
| The database schema version | `dart run drift_dev make-migrations` (see the comment in `app_database.dart`) |

## Run the checks

Before you send a change, run these from the repository root. CI runs the same ones.

```bash
dart format .                  # format (CI fails on unformatted code)
flutter analyze                # static analysis, all Dart packages
```

### Tests

| What | Command |
|---|---|
| The app (widget tests, every design) | `cd app && flutter test` |
| Shared logic | `cd shared && dart test` |
| The server | `cd server && npm ci && npm test` (and `npm run typecheck`) |

Notes:

- **Fedora and ccache.** If `flutter test` fails with "Building native assets failed", take ccache off your `PATH` for the command. See [the troubleshooting note](docs/dev-setup-fedora.md#troubleshooting-flutter-test-fails-with-building-native-assets-failed).
- **"Unable to connect to flutter_tester process"** is a test runner hiccup, not your code. Run the command again, or add `--concurrency=1`.
- Shared tests should pass in any timezone: `TZ=America/New_York dart test` (CI tries three).

### Tests that need more

- **Two devices syncing through the real server.** In one terminal, start a server with an empty in-memory database:
  ```bash
  cd server && npm ci
  DATABASE_URL=:memory: SETUP_SECRET=live-test-secret PORT=8787 npm run dev
  ```
  In a second terminal, run the live test, then stop the server with `Ctrl+C`:
  ```bash
  cd app
  TASKWISE_TEST_SERVER=http://localhost:8787 \
    TASKWISE_TEST_SETUP_SECRET=live-test-secret flutter test --tags live
  ```
- **The real app in a window** (places, location reminders, the map; needs internet for map tiles):
  ```bash
  cd app && flutter test integration_test/location_test.dart -d linux
  ```
  Add `--dart-define=SHOTS=<folder>` to save screenshots.
- **iPhone location logic**, without an iPhone (needs [podman](https://podman.io)):
  ```bash
  tools/geofence_sim/run.sh test     # the Swift unit tests, on Linux
  tools/geofence_sim/run.sh          # the walk simulator
  ```

### Design screenshots

If you changed how a screen looks, make new screenshots and look at them for every design:

```bash
cd app && flutter test integration_test/design_tour_test.dart -d linux --dart-define=SHOTS=$PWD/../design
```

Add `--dart-define=DESIGNS=brutal` to shoot one design only. See [design/README.md](design/README.md). Commit the pictures that changed.

## Code style

- Dart: `dart format` and `flutter analyze` must be clean. Single quotes, declared return types, no `print` (see `analysis_options.yaml`).
- TypeScript: `npm run typecheck` must pass.
- Add a test for logic (data, repeats, sync, reminders). Keep comments short and explain *why*.
- Never put secrets, passwords, tokens or personal addresses in the repository. The server reads its secrets from environment variables only.
- Adding a package? Check it is maintained and works on Windows, Linux and iOS, and pin its version.

## Commits

Look at `git log --oneline`. A message is a short title in the imperative, then (when useful) a list of what changed:

```
M8: designs and design picker

- Four designs selectable per device in Settings > Appearance > Design
- UI split into lib/ui/shared/ and lib/ui/designs/<name>/
```

- Milestone work: `M<number>: <title>`. A release with fixes only: `v<version>: <what changed>`. Other work: a plain title such as `Server: rename app.ts to api.ts`.
- One change per commit, and tests and docs in the same commit as the code.
- Write what changed in the "Unreleased" part of [CHANGELOG.md](CHANGELOG.md) when a user would notice it.

## Releases

Only a maintainer does this.

1. Move the "Unreleased" entries in [CHANGELOG.md](CHANGELOG.md) under a new heading `## [<version>] - <YYYY-MM-DD>` (and add a fresh empty "Unreleased" above it). Update the links at the bottom.
2. Bump `version:` in `app/pubspec.yaml` (for example `0.6.0+9`: the part before `+` is the version, the number after it is the build number, which goes up by one every release).
3. Commit, push, and wait for CI to turn green.
4. Push a tag that matches the version:
   ```bash
   git tag v0.6.0
   git push origin v0.6.0
   ```
5. The **Release builds** workflow builds Linux, Windows and an unsigned iOS file, and creates a **draft** release named after the tag. The text of the release is the matching section of the changelog (or GitHub's generated notes if there is none). The workflow stops with an error if the tag and the pubspec version differ.
6. Download the files to try them: `gh release download v0.6.0 --dir taskwise-0.6.0`.
7. Open the draft on GitHub, check the text and the files, and press **Publish release**. Until then nobody else can see it.

You can also run **Release builds** by hand from the Actions tab. That makes build files you can download for a week, but no release.

## Questions

Open an issue on GitHub.
