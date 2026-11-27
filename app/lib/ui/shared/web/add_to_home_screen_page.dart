import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/web_shell.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// In an iPhone Safari tab, shows [AddToHomeScreenPage] before [child]
/// (the design's shell), once per tab. A Safari tab and the Home Screen app
/// keep separate storage on iOS, so most people should sign in only in the
/// Home Screen app. Elsewhere it is just [child]. Wraps the shell (see
/// app.dart).
class AddToHomeScreenGate extends ConsumerStatefulWidget {
  const AddToHomeScreenGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AddToHomeScreenGate> createState() =>
      _AddToHomeScreenGateState();
}

class _AddToHomeScreenGateState extends ConsumerState<AddToHomeScreenGate> {
  late bool _guide;

  @override
  void initState() {
    super.initState();
    final shell = ref.read(webShellProvider);
    _guide = shell.isIosBrowserTab && !shell.guideDismissed;
  }

  @override
  Widget build(BuildContext context) {
    if (!_guide) return widget.child;
    return AddToHomeScreenPage(
      onContinue: () {
        ref.read(webShellProvider).dismissGuide();
        setState(() => _guide = false);
      },
    );
  }
}

/// "Add Taskwise to your Home Screen": Share → Add to Home Screen, with
/// "Continue in the browser anyway" below.
class AddToHomeScreenPage extends StatelessWidget {
  const AddToHomeScreenPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget step(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: Spacing.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.add_to_home_screen,
                    size: 48,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    l10n.homeScreenGuideTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    l10n.homeScreenGuideWhy,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.xl),
                  step(Icons.ios_share, l10n.homeScreenGuideStep1),
                  step(Icons.add_box_outlined, l10n.homeScreenGuideStep2),
                  step(Icons.home_outlined, l10n.homeScreenGuideStep3),
                  const SizedBox(height: Spacing.xl),
                  TextButton(
                    onPressed: onContinue,
                    child: Text(l10n.homeScreenGuideContinue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
