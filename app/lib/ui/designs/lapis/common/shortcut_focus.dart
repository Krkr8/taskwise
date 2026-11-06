import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Focus for the quick add field, so a keyboard shortcut can reach it.
final quickAddFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'quick add');
  ref.onDispose(node.dispose);
  return node;
});

/// Focus for the task search field.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});
