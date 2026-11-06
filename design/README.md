# Design screenshots

Every main screen of every design, in four looks: desktop light, desktop dark, phone light and phone Arabic. The folders are `design/<design>/<look>/`; the designs are Classic, Lapis, Slate & Indigo (`slate`) and Brutal (see `docs/architecture.md`).

They are made by the design tour (`app/integration_test/design_tour_test.dart`) from realistic sample tasks:

    cd app && flutter test integration_test/design_tour_test.dart -d linux --dart-define=SHOTS=$PWD/../design

Add `--dart-define=DESIGNS=brutal` to shoot only some designs.

Each design's `README.md` explains its idea. Lapis's and Slate & Indigo's app icons are kept as `app-icon.png` for reference; the app itself uses Brutal's icon.
