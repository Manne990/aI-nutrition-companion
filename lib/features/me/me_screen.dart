import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/onboarding.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_section_card.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({
    super.key,
    required this.profile,
    required this.onResetOnboarding,
  });

  final OnboardingProfile profile;
  final Future<void> Function() onResetOnboarding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Me', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Goals and preferences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.primaryGoal),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppChip(
                    label: '${profile.proteinGoalGrams.round()}g protein',
                    icon: Icons.fitness_center,
                  ),
                  AppChip(label: profile.coachingTone, icon: Icons.chat_bubble),
                  for (final preference in profile.dietaryPreferences)
                    AppChip(label: preference),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'AI provider',
          child: Text(
            'Mock mode is enabled until a provider, model, and local token are configured.',
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Health and privacy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health, camera, and token access remain off until a feature needs consent.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: 'Reset onboarding',
                icon: Icons.restart_alt,
                onPressed: onResetOnboarding,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
