import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_settings.dart';
import '../../../state/providers.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// Settings → Appearance → Design: picks one of the app's designs.
///
/// Shared by every design's Settings page, so it looks like a normal chip
/// row in each (the chips take the current design's theme).
class DesignPicker extends ConsumerWidget {
  const DesignPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).design;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final design in AppDesign.values)
          ChoiceChip(
            key: ValueKey('design-${design.name}'),
            avatar: _Swatch(designSwatch(design)),
            label: Text(designName(context, design)),
            selected: design == current,
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(settingsRepositoryProvider).setDesign(design),
          ),
      ],
    );
  }
}

/// The design's name as shown in Settings.
String designName(BuildContext context, AppDesign design) {
  final l10n = context.l10n;
  return switch (design) {
    AppDesign.classic => l10n.designClassic,
    AppDesign.lapis => l10n.designLapis,
    AppDesign.slate => l10n.designSlate,
    AppDesign.brutal => l10n.designBrutal,
  };
}

/// Two colours that stand for each design: its ground and its accent.
(Color, Color) designSwatch(AppDesign design) => switch (design) {
  AppDesign.classic => (const Color(0xFFF4FBF9), const Color(0xFF00897B)),
  AppDesign.lapis => (const Color(0xFFF4F5F9), const Color(0xFF2B48C4)),
  AppDesign.slate => (const Color(0xFFF8FAFC), const Color(0xFF4F46E5)),
  AppDesign.brutal => (const Color(0xFFF7F0E1), const Color(0xFFFFD23F)),
};

class _Swatch extends StatelessWidget {
  const _Swatch(this.colors);

  final (Color, Color) colors;

  @override
  Widget build(BuildContext context) {
    final (ground, accent) = colors;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: ground,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF141414), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
    );
  }
}
