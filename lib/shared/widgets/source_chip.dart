import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/meal_suggestion.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final NutritionSource source;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.leafGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          _label,
          style: const TextStyle(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String get _label {
    return switch (source) {
      NutritionSource.aiEstimated => 'AI-estimated',
      NutritionSource.userConfirmed => 'User-confirmed',
      NutritionSource.databaseVerified => 'Database-verified',
      NutritionSource.fallback => 'Fallback data',
    };
  }
}
