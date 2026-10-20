import 'package:flutter/material.dart';

import '../settings/settings_page.dart';
import '../tasks/labels.dart';
import '../tasks/task_list_page.dart';
import '../theme/tokens.dart';

/// Top-level navigation: bottom bar on phones, side rail on wider screens.
/// (The Week destination joins in M3.)
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  int _index = 0;

  static const _pages = [TaskListPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final page = IndexedStack(index: _index, children: _pages);
    final destinations = [
      (Icons.check_circle_outline, Icons.check_circle, l10n.navTasks),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    if (compact) {
      return Scaffold(
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationRailDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
