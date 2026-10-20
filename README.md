# Taskwise

A personal, self-hosted to-do and reminders app for Windows, Linux and iOS, with a small sync server you run yourself.

> Status: early development (milestone M0, project setup). See [SPEC.md](SPEC.md) for the full specification and progress log.

## Repository layout

| Path | What it is |
|---|---|
| `app/` | Flutter app (Linux, Windows, iOS) |
| `server/` | Dart sync server (placeholder until M5) |
| `shared/` | Models, sync protocol and recurrence logic shared by app and server |
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

## License

[MIT](LICENSE)
