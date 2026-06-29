import 'package:flutter/material.dart';

import '../../domain/models/meal_suggestion.dart';
import 'app_chip.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final NutritionSource source;

  @override
  Widget build(BuildContext context) {
    return AppChip(label: _label, tone: AppChipTone.success);
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
