import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/web_shell.dart';

/// On the web: adds the browser's safe areas (the iPhone's notch and home
/// indicator, [WebShell.safeAreaInsets]) to the [MediaQuery] padding, so the
/// designs' `SafeArea`s keep clear of them as in the native apps. Outside
/// the browser it changes nothing. Used in app.dart's `builder`.
class BrowserSafeArea extends ConsumerStatefulWidget {
  const BrowserSafeArea({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BrowserSafeArea> createState() => _BrowserSafeAreaState();
}

class _BrowserSafeAreaState extends ConsumerState<BrowserSafeArea> {
  StreamSubscription<EdgeInsets>? _sub;
  EdgeInsets _insets = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webShellProvider).safeAreaInsets.listen((insets) {
      if (insets != _insets) setState(() => _insets = insets);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    // Always a MediaQuery, so the app keeps its state when insets change.
    if (_insets == EdgeInsets.zero) {
      return MediaQuery(data: data, child: widget.child);
    }
    final view = data.viewPadding;
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(view.left, _insets.left),
      math.max(view.top, _insets.top),
      math.max(view.right, _insets.right),
      math.max(view.bottom, _insets.bottom),
    );
    // Like Flutter's own: the keyboard covers the bottom safe area.
    final keyboard = data.viewInsets;
    final padding = EdgeInsets.fromLTRB(
      math.max(0, viewPadding.left - keyboard.left),
      math.max(0, viewPadding.top - keyboard.top),
      math.max(0, viewPadding.right - keyboard.right),
      math.max(0, viewPadding.bottom - keyboard.bottom),
    );
    return MediaQuery(
      data: data.copyWith(viewPadding: viewPadding, padding: padding),
      child: widget.child,
    );
  }
}
