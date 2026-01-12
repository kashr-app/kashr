import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_page.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:kashr/theme.dart';

class OnboardingReady extends StatelessWidget {
  const OnboardingReady({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re Ready!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Start by creating your first account and tracking your finances.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildQuickTip(
                  context,
                  icon: iconAccounts,
                  text: 'Create accounts',
                ),
                const SizedBox(height: 12),
                _buildQuickTip(
                  context,
                  icon: iconTurnover,
                  text: 'Tag transactions',
                ),
                const SizedBox(height: 12),
                _buildQuickTip(context, icon: iconSavings, text: 'Track goals'),
                const SizedBox(height: 12),
                _buildQuickTip(
                  context,
                  icon: iconAnalytics,
                  text: 'Get insights',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Find help anytime in Settings → Help',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              return SwitchListTile(
                title: Row(
                  children: [
                    Icon(iconThemeMode),
                    SizedBox(width: 8),
                    Text('Enable ${ThemeMode.dark.title()} mode?'),
                  ],
                ),
                value: state.themeMode == ThemeMode.dark,
                onChanged: (value) => context.read<SettingsCubit>().setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTip(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
