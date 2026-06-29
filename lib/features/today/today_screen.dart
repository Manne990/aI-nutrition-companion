import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/meal_suggestion.dart';
import '../../services/adapters/nutrition_companion_adapter.dart';
import '../../shared/widgets/app_section_card.dart';
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
          child: Row(
            children: [
              Expanded(
                child: _Metric(label: 'Last meal', value: '3h ago'),
              ),
              Expanded(
                child: _Metric(label: 'Protein', value: '68 / 110g'),
              ),
              Expanded(
                child: _Metric(label: 'Energy', value: '1,420 kcal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Quick Log',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              ActionChip(label: Text('Greek yogurt'), onPressed: null),
              ActionChip(label: Text('Chicken salad'), onPressed: null),
              ActionChip(label: Text('Banana'), onPressed: null),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Companion note',
          child: Text(
            'You are close to your protein target. A simple high-protein snack keeps dinner flexible.',
          ),
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
            Container(
              height: 156,
              decoration: BoxDecoration(
                color: AppColors.deepGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.ramen_dining,
                  color: AppColors.peach,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SourceChip(source: suggestion.source),
            const SizedBox(height: 12),
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(suggestion.summary),
            const SizedBox(height: 16),
            Row(
              children: [
                _Pill(text: '${suggestion.proteinGrams}g protein'),
                const SizedBox(width: 8),
                _Pill(text: '${suggestion.calories} kcal'),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Change'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
