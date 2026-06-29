import 'nutrition.dart';

export 'nutrition.dart' show NutritionSource;

class MealSuggestion {
  const MealSuggestion({
    required this.title,
    required this.summary,
    required this.proteinGrams,
    required this.calories,
    required this.prepMinutes,
    required this.ingredientAvailability,
    required this.nutritionRationale,
    required this.source,
    this.imageAssetKey,
  });

  final String title;
  final String summary;
  final int proteinGrams;
  final int calories;
  final int prepMinutes;
  final String ingredientAvailability;
  final String nutritionRationale;
  final NutritionSource source;
  final String? imageAssetKey;
}
