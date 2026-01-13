import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kashr/app_gate.dart';
import 'package:kashr/onboarding/onboarding_page.dart';
import 'package:kashr/settings/model/feature_tip.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpRoute extends GoRouteData with $HelpRoute {
  const HelpRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HelpPage();
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text('Explain App'),
                  subtitle: const Text('View onboarding screens again'),
                  leading: const Icon(Icons.info),
                  onTap: () => const OnboardingRoute().go(context),
                ),
                ListTile(
                  title: const Text('Ask Questions'),
                  subtitle: const Text('Get help on GitHub'),
                  leading: const Icon(Icons.help),
                  onTap: () => _launchGitHubUrl(
                    context,
                    'https://github.com/kashr-app/kashr/issues/new?labels=question',
                  ),
                ),
                ListTile(
                  title: const Text('Report Problems'),
                  subtitle: const Text('File a bug report'),
                  leading: const Icon(Icons.bug_report),
                  onTap: () => _launchGitHubUrl(
                    context,
                    'https://github.com/kashr-app/kashr/issues/new?labels=bug',
                  ),
                ),
                ListTile(
                  title: const Text('Propose Features'),
                  subtitle: const Text('Request new features'),
                  leading: const Icon(Icons.lightbulb),
                  onTap: () => _launchGitHubUrl(
                    context,
                    'https://github.com/kashr-app/kashr/issues/new?labels=feature',
                  ),
                ),
                ListTile(
                  title: const Text('Feature Tips'),
                  subtitle: const Text('Show feature tips again'),
                  leading: const Icon(Icons.refresh),
                  onTap: () => _showResetFeatureTipsDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchGitHubUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  Future<void> _showResetFeatureTipsDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Feature Tips?'),
          content: const Text(
            'This will show all feature tips again. You can also reset '
            'individual tips.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 1),
              child: const Text('Individual'),
            ),
            TextButton(
              onPressed: () {
                context.read<SettingsCubit>().resetAllFeatureTips();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All feature tips have been reset'),
                  ),
                );
              },
              child: const Text('Reset All'),
            ),
          ],
        );
      },
    );

    if (context.mounted && result == 1) {
      _showIndividualFeatureTipsDialog(context);
    }
  }
}

void _showIndividualFeatureTipsDialog(BuildContext context) {
  final cubit = context.read<SettingsCubit>();

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Reset Individual Tips',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...FeatureTip.values.map((tip) {
                  final isShown = state.featureTipsShown[tip] ?? false;
                  return ListTile(
                    title: Text(tip.displayName),
                    trailing: isShown
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              cubit.resetFeatureTip(tip);
                            },
                          )
                        : const Icon(Icons.lock_clock, color: Colors.grey),
                    subtitle: Text(
                      isShown ? 'Shown' : 'Not shown yet',
                      style: TextStyle(color: isShown ? null : Colors.grey),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}
