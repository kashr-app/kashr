import 'package:flutter/material.dart';

class OnboardingCoreConcepts extends StatelessWidget {
  const OnboardingCoreConcepts({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Track with Tags',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Organize your transactions by tagging them. '
            'One transaction can have multiple tags.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildFeatureItem(
            context,
            icon: Icons.local_offer,
            title: 'Create tags on the fly',
            description: 'No setup needed. Create and organize tags as you go.',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            context,
            icon: Icons.auto_awesome,
            title: 'Smart suggestions',
            description: 'The app learns and proposes tags based on your '
                'history.',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            context,
            icon: Icons.call_split,
            title: 'Split transactions',
            description: 'Tag parts of a transaction differently to track '
                'multiple things.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
