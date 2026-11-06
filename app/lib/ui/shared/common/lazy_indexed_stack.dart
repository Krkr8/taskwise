import 'package:flutter/widgets.dart';

/// An [IndexedStack] that builds a page only once it has been shown, then
/// keeps it (and its state) like an [IndexedStack] does.
///
/// The app's tabs use it so opening the app, or switching designs, builds
/// only the tab on screen instead of all of them.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final _shown = <int>{};

  @override
  Widget build(BuildContext context) {
    _shown.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (final (i, child) in widget.children.indexed)
          _shown.contains(i) ? child : const SizedBox.shrink(),
      ],
    );
  }
}
