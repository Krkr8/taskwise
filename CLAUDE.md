# Taskwise: start here

**`SPEC.md` is the source of truth.** At the start of every chat:
1. Read SPEC.md §0 (rules) and §7 Progress Log, starting with **"Where we left off"**. It holds the current state, what the owner still has to confirm, and what comes next.
2. Work on one milestone at a time. Start each milestone in plan mode and wait for the owner's approval.
3. Finish a milestone with `flutter analyze` and all tests, then a commit `M<n>: <title>` and a push. Update the Progress Log and give the owner beginner-friendly test steps.

## Quick facts
- Layout: `app/` (Flutter: Windows, Linux, iOS), `shared/` (Dart models and logic), `server/` (TypeScript + Hono sync server on Vercel with Turso). API: `docs/sync-api.md`. Where everything lives, and how to change a screen in every design: `docs/architecture.md`.
- Designs: the app has four (Classic, Lapis, Slate & Indigo, Brutal), picked per device in Settings. Each has its own screens in `app/lib/ui/designs/<name>/`, with shared screens in `app/lib/ui/shared/`. A screen change usually has to be made in each design's copy.
- Tests:
  - `cd app && flutter test`. Take ccache off `PATH` first (`docs/dev-setup-fedora.md`). On "Unable to connect to flutter_tester process", re-run or add `--concurrency=1`.
  - `cd shared && dart test`
  - `cd server && npm test`
  - The live two-device sync test needs a local server: see the top of `app/test/sync/live_server_test.dart`.
  - Location reminders without the iPhone: `tools/geofence_sim/run.sh` (walk simulator over the real Swift `GeofenceEngine`, in podman), `run.sh test` (Swift unit tests on Linux), and `cd app && flutter test integration_test/location_test.dart -d linux` (real app in a window; add `--dart-define=SHOTS=<dir>` for screenshots).
- Design screenshots: `cd app && flutter test integration_test/design_tour_test.dart -d linux --dart-define=SHOTS=$PWD/../design` (every main screen of every design in 4 looks; `--dart-define=DESIGNS=brutal` for one; see `design/README.md`).
- Performance with 2,000 tasks: `docs/performance.md` (profile build: `cd app && flutter drive --profile -d linux --driver=test_driver/integration_test.dart --target=integration_test/performance_test.dart`).
- Logs: `appLog` (`app/lib/logging/app_log.dart`), shown in Settings → About → View logs. Never log task titles, notes, places or tokens.
- Releases:
  - Add the version's section to `CHANGELOG.md` and bump `app/pubspec.yaml` and `app/lib/version.dart`, then push a tag `v<version>`. The release workflow builds draft releases for Linux, Windows and unsigned iOS.
  - Download the files for the owner with `gh release download v<version> --dir ~/Downloads/taskwise-<version>`.
- Secrets live only in `~/.config/taskwise/server-secrets.env` on the owner's laptop. Never in the repo or in chat. Ask for a new secret with the private secret box, never in chat.
- The owner develops on Fedora 44 and also tests on a Windows PC and an iPhone (installed with iloader). They are comfortable with a terminal but not with mobile development, so spell out device steps.
- Screenshots from the owner are in `tempscreenshot/` (ignored by git).
