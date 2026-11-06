import 'package:flutter/material.dart';

import '../../../version.dart';
import '../tasks/labels.dart';
import 'logs_page.dart';

/// Settings → About: the version and the logs. Shared by every design.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutVersion(appVersion)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(l10n.aboutViewLogs),
          subtitle: Text(l10n.aboutViewLogsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const LogsPage())),
        ),
      ],
    );
  }
}
