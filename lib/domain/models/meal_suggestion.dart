enum NutritionSource { aiEstimated, userConfirmed, databaseVerified, fallback }

class MealSuggestion {
  const MealSuggestion({
    required this.title,
    required this.summary,
    required this.proteinGrams,
    required this.calories,
    required this.source,
  });

  final String title;
  final String summary;
  final int proteinGrams;
  final int calories;
  final NutritionSource source;
}
