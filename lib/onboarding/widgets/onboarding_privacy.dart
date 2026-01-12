import 'package:flutter/material.dart';

class OnboardingPrivacy extends StatelessWidget {
  const OnboardingPrivacy({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Your Privacy Matters',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your data stays on your device. No cloud required. No data sales.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {
              _showPrivacyDetails(context);
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('Show more information'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Data Storage'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You own your data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'All your financial data is stored locally on your device. '
                'We don\'t have any access to it.',
              ),
              SizedBox(height: 16),
              Text(
                'Optional backups',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You can create encrypted backups and export them (e.g. '
                'Nextcloud/WebDAV). The encryption key stays with you.',
              ),
              SizedBox(height: 16),
              Text(
                'No tracking, no ads',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Kashr doesn\'t track your usage, shows no ads, nor sells your data. '
                'This is open source software built with your privacy in mind.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Love it'),
          ),
        ],
      ),
    );
  }
}
