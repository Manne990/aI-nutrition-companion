import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/meal_suggestion.dart';
import '../../services/adapters/nutrition_companion_adapter.dart';
import '../../shared/widgets/ai_message_bubble.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_metric_row.dart';
import '../../shared/widgets/app_section_card.dart';
import '../../shared/widgets/food_image_card.dart';
import '../../shared/widgets/source_chip.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    this.adapter = const MockNutritionCompanionAdapter(),
  });

  final NutritionCompanionAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final suggestion = adapter.nextMealSuggestion();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'AI Nutrition Companion',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'What should I eat next?',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        _SuggestionCard(suggestion: suggestion),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Daily rhythm',
          child: AppMetricRow(
            metrics: [
              AppMetricData(label: 'Last meal', value: '3h ago'),
              AppMetricData(label: 'Protein', value: '68 / 110g'),
              AppMetricData(label: 'Energy', value: '1,420 kcal'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Quick Log',
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.warmSurface,
          trailing: AppChip(label: 'Habit detected', tone: AppChipTone.inverse),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppChip(label: 'Greek yogurt', tone: AppChipTone.inverse),
              AppChip(label: 'Chicken salad', tone: AppChipTone.inverse),
              AppChip(label: 'Banana', tone: AppChipTone.inverse),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AiMessageBubble(
          message:
              'You are close to your protein target. A simple high-protein snack keeps dinner flexible.',
          actions: [
            AiChoiceChip(
              label: 'Show options',
              primary: true,
              onPressed: () {},
            ),
            AiChoiceChip(label: 'Not now', onPressed: () {}),
          ],
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final MealSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FoodImageCard(
              icon: Icons.ramen_dining,
              semanticLabel: 'Suggested meal image placeholder',
            ),
            const SizedBox(height: 18),
            const AppChip(
              label: 'Suggested next',
              icon: Icons.auto_awesome,
              tone: AppChipTone.accent,
            ),
            const SizedBox(height: 12),
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(suggestion.summary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChip(label: '${suggestion.proteinGrams}g protein'),
                AppChip(label: '${suggestion.calories} kcal'),
                SourceChip(source: suggestion.source),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(label: 'Accept', onPressed: () {}),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppSecondaryButton(label: 'Change', onPressed: () {}),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
