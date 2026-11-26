# app/web

The files of the browser build (Flutter web). `index.html`, `manifest.json`,
`favicon.png` and `icons/` are Flutter's defaults (`flutter create --platforms web`).

## The database files

The web app's database is drift's WebAssembly build of SQLite
(`AppDatabase.openConnection` in `lib/data/db/app_database.dart`). It needs two
files next to `index.html`. They must match the `drift` and `sqlite3` versions in
the repo's `pubspec.lock`: download them again whenever those change.

| File | Version | Source | sha256 |
| --- | --- | --- | --- |
| `sqlite3.wasm` | sqlite3 3.7.1 | https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.7.1/sqlite3.wasm | `87c1869b533ea4b6daa1f4dc6aa7e9cf3dae6e6ea53f8ed57080c08eb5f64303` |
| `drift_worker.js` | drift 2.35.2 | https://github.com/simolus3/drift/releases/download/drift-2.35.2/drift_worker.js | `191fc9db018d2bbecb1723e81118fcf2c5c094df8644c2fcba2ed51df061e90a` |

The sha256 values match the digests GitHub shows for these release assets.

To update them:

```sh
# Versions from pubspec.lock (repo root)
grep -A6 '^  sqlite3:\|^  drift:' ../../pubspec.lock | grep version
dir=$(mktemp -d)
gh release download sqlite3-<version> -R simolus3/sqlite3.dart -p sqlite3.wasm -D "$dir"
gh release download drift-<version> -R simolus3/drift -p drift_worker.js -D "$dir"
head -c 4 "$dir/sqlite3.wasm" | od -An -tx1   # must be 00 61 73 6d
sha256sum "$dir"/*                            # compare with the release page
cp "$dir/sqlite3.wasm" "$dir/drift_worker.js" .
```

Then update the table above.
