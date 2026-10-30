# Taskwise

A personal, self-hosted to-do and reminders app for Windows, Linux and iOS, with a small sync server you host free on Vercel.

> Status: early development. Milestone M1 (core app, local only) is done. See [SPEC.md](SPEC.md) for the full specification and progress log.

## Install

Builds for each platform are attached to [GitHub Releases](https://github.com/Krkr8/taskwise/releases):

- [Linux (Fedora)](docs/install-linux.md)
- [Windows 11](docs/install-windows.md)
- [iPhone with SideStore](docs/install-ios-sidestore.md) (no Mac needed; see also [what works with a free Apple ID](docs/ios-free-apple-id.md))

Maintainers make a release by bumping `version:` in `app/pubspec.yaml`, then pushing a matching tag (e.g. `git tag v0.1.0 && git push origin v0.1.0`). The **Release builds** workflow builds all three platforms and attaches them to a **draft** release, which stays private until it is published by hand. It can also be run by hand from the Actions tab to get build artifacts without a release.

## Repository layout

| Path | What it is |
|---|---|
| `app/` | Flutter app (Linux, Windows, iOS) |
| `server/` | Sync server: TypeScript on Vercel from M5 (currently a Dart placeholder) |
| `shared/` | Dart models and logic used by the app, plus sync API fixtures (from M5) |
| `docs/` | Setup guides |
| `.github/` | CI workflows |

The three Dart packages form a [pub workspace](https://dart.dev/tools/pub/workspaces), so one `flutter pub get` at the repo root fetches everything.

## Development

Set up a Fedora machine with [docs/dev-setup-fedora.md](docs/dev-setup-fedora.md), then:

```bash
flutter pub get                                # fetch dependencies for all packages
dart format .                                  # format
flutter analyze                                # static analysis (all packages)
(cd app && flutter test)                       # app tests
(cd shared && dart test) && (cd server && dart test)
(cd app && flutter run -d linux)               # run the app
```

### Generated code

Generated files are committed, so a fresh clone runs without extra steps. After changing their sources, regenerate from `app/` (CI fails if they're out of date):

| You changed | Run |
|---|---|
| Database tables (`app/lib/data/db/`) | `dart run build_runner build --delete-conflicting-outputs` |
| UI text (`app/lib/l10n/*.arb`) | `flutter gen-l10n` |
| Database schema version | `dart run drift_dev make-migrations` (see the comment in `app_database.dart`) |

### Data location

The app keeps its SQLite database in the per-user app-support folder, e.g. `~/.local/share/io.github.krkr8.taskwise/taskwise.sqlite` on Linux. Delete that folder to start fresh.

## License

[MIT](LICENSE)
