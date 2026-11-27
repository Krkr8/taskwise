import 'package:flutter/widgets.dart' show EdgeInsets;

bool isIosBrowserTab() => false;

bool guideDismissed() => false;

void dismissGuide() {}

Stream<void> newVersionReady() => const Stream.empty();

void reloadToNewVersion() {}

Stream<EdgeInsets> safeAreaInsets() => const Stream.empty();
