import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'ai_message_bubble.dart';
import 'app_action_buttons.dart';
import 'app_chip.dart';
import 'app_metric_row.dart';
import 'app_section_card.dart';
import 'food_image_card.dart';

class DesignSystemDemo extends StatelessWidget {
  const DesignSystemDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Design system demo',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            eyebrow: 'Suggested next',
            title: 'Reusable meal card',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FoodImageCard(
                  icon: Icons.ramen_dining,
                  semanticLabel: 'Demo meal image placeholder',
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppChip(label: '~22 min'),
                    AppChip(label: 'High protein', tone: AppChipTone.accent),
                    AppChip(label: 'AI-estimated', tone: AppChipTone.success),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const AppMetricRow(
                  metrics: [
                    AppMetricData(label: 'Protein', value: '32g'),
                    AppMetricData(label: 'Energy', value: '410 kcal'),
                    AppMetricData(label: 'Source', value: 'Mock AI'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Sounds perfect',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppIconActionButton(
                      icon: Icons.refresh,
                      tooltip: 'Refresh suggestion',
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AiMessageBubble(
            message:
                'I can explain what changed and keep the next action practical.',
            actions: [
              AiChoiceChip(
                label: 'Yes, show me',
                primary: true,
                onPressed: () {},
              ),
              AiChoiceChip(label: 'Keep as is', onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
