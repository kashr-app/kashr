import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kashr/app_gate.dart';
import 'package:kashr/settings/model/amazon_order_behavior.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_state.dart';

class AmazonOrderDetectionRoute extends GoRouteData
    with $AmazonOrderDetectionRoute {
  const AmazonOrderDetectionRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AmazonOrderDetectionPage();
  }
}

class AmazonOrderDetectionPage extends StatelessWidget {
  const AmazonOrderDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amazon Order Detection')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'About this feature',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kashr can detect Amazon order IDs in your transaction '
                          'descriptions and provide quick access to the order '
                          'details page on Amazon.\n\n'
                          'Since bank transactions don\'t show what you '
                          'purchased, this feature helps you quickly look up '
                          'your order details by tapping the detected order ID.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) => Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.touch_app),
                        title: const Text('Tap Behavior'),
                        subtitle: Text(state.amazonOrderBehavior.displayName),
                        onTap: () async {
                          final newValue = await showAmazonOrderBehaviorDialog(
                            context,
                            state.amazonOrderBehavior,
                          );
                          if (newValue != null && context.mounted) {
                            await context
                                .read<SettingsCubit>()
                                .setAmazonOrderBehavior(newValue);
                          }
                        },
                      ),
                      if (state.amazonOrderBehavior ==
                          AmazonOrderBehavior.openOnTld)
                        ListTile(
                          leading: const Icon(Icons.public),
                          title: const Text('Default Marketplace'),
                          subtitle: Text(state.amazonTld.displayName),
                          onTap: () async {
                            final newValue = await showAmazonTldDialog(
                              context,
                              state.amazonTld,
                            );
                            if (newValue != null && context.mounted) {
                              await context.read<SettingsCubit>().setAmazonTld(
                                newValue,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
