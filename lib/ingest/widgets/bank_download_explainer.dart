import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Answers what a bank download does before the app asks for anything.
///
/// Content only, with no way in or out, so the download sheet can put it in
/// front of the login and the banks page can leave it lying around. One copy
/// keeps the two from drifting apart.
class BankDownloadExplainer extends StatelessWidget {
  const BankDownloadExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Section(
          icon: Icons.account_balance_outlined,
          title: 'What it does',
          body:
              'Kashr signs in to your bank from this device and asks for '
              'your turnovers. That is all it asks for, and it cannot move '
              'money.',
        ),
        _Section(
          icon: Icons.visibility_off_outlined,
          title: 'Who can see it',
          body:
              'Nobody but you. There is no Kashr server. Your turnovers go '
              'from your bank straight into this app, with no third party in '
              'between.',
        ),
        _Section(
          icon: Icons.phone_android_outlined,
          title: 'Where it ends up',
          body:
              'In this app on this device, and nowhere else. Nothing is '
              'uploaded, nothing is sold, and nothing is tracked. Connecting '
              'asks for your comdirect sign-in details, which are stored on '
              'this device only.',
        ),
        _Section(
          icon: Icons.code,
          title: 'Why you can check',
          body:
              'Kashr is open source. Everything above is in the code, and '
              'anyone can read it.',
          link: _SourceLink(),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    this.link,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (link != null) link!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () => launchUrl(
          Uri.parse('https://github.com/kashr-app/kashr'),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text('Read the source'),
      ),
    );
  }
}
