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

  MealSuggestion copyWith({
    String? title,
    String? summary,
    int? proteinGrams,
    int? calories,
    int? prepMinutes,
    String? ingredientAvailability,
    String? nutritionRationale,
    NutritionSource? source,
    String? imageAssetKey,
  }) {
    return MealSuggestion(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      calories: calories ?? this.calories,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      ingredientAvailability:
          ingredientAvailability ?? this.ingredientAvailability,
      nutritionRationale: nutritionRationale ?? this.nutritionRationale,
      source: source ?? this.source,
      imageAssetKey: imageAssetKey ?? this.imageAssetKey,
    );
  }
}

List<MealSuggestion> localizeMealSuggestions({
  required List<MealSuggestion> suggestions,
  required DailySummary summary,
  required UserPreferences preferences,
  required List<QuickLogSuggestion> quickLogSuggestions,
}) {
  if (suggestions.isEmpty) {
    return suggestions;
  }

  final proteinRationale = _proteinRationale(summary);
  final localSummary = _localSummary(summary, preferences);
  final sourceContext = _sourceContext(summary);
  final availability = _availabilityContext(
    suggestions.first.ingredientAvailability,
    quickLogSuggestions,
  );

  return [
    suggestions.first.copyWith(
      summary: '$localSummary $sourceContext',
      ingredientAvailability: availability,
      nutritionRationale: proteinRationale,
    ),
    ...suggestions.skip(1),
  ];
}

String _proteinRationale(DailySummary summary) {
  final remaining = summary.proteinRemainingGrams;
  if (remaining == null) {
    return summary.hasMeals
        ? 'Uses local meal context without a protein target'
        : 'Starts with practical protein context';
  }
  if (remaining <= 0) {
    return 'Protein target is covered; choose for appetite and routine';
  }
  if (!summary.hasMeals) {
    return 'Starts today toward the ${summary.goal!.proteinGrams.round()}g protein target';
  }
  if (remaining >= 40) {
    return 'Closes a large ${remaining.round()}g protein gap';
  }
  return 'Covers the remaining ${remaining.round()}g protein gap';
}

String _localSummary(DailySummary summary, UserPreferences preferences) {
  final preference = preferences.dietaryPreferences.firstOrNull;
  final preferenceCopy = preference == null ? '' : ' with $preference in mind';
  if (!summary.hasMeals) {
    return 'No confirmed meals yet today; start with a simple option$preferenceCopy.';
  }
  final lastMeal = summary.meals.last;
  return 'After ${lastMeal.name}, this is a practical next step$preferenceCopy.';
}

String _sourceContext(DailySummary summary) {
  if (summary.itemsWithMissingNutrition > 0) {
    return 'Some logged nutrition is still unconfirmed, so treat the rationale as guidance.';
  }
  final sources = summary.meals
      .expand((meal) => meal.items)
      .map((item) => item.food.source.source)
      .toSet();
  if (sources.contains(NutritionSource.fallback)) {
    return 'Fallback nutrition is marked, so confirm details when precision matters.';
  }
  if (sources.contains(NutritionSource.aiEstimated)) {
    return 'AI-estimated values are directional, not verified facts.';
  }
  if (sources.any(
    (source) =>
        source == NutritionSource.databaseVerified ||
        source == NutritionSource.userConfirmed,
  )) {
    return 'Confirmed or provider-verified local data is visible for today.';
  }
  return 'No verified meal source is available yet.';
}

String _availabilityContext(
  String fallback,
  List<QuickLogSuggestion> quickLogSuggestions,
) {
  final suggestion = quickLogSuggestions.firstOrNull;
  if (suggestion == null) {
    return fallback;
  }
  return 'Local ${suggestion.timeWindowLabel.toLowerCase()} option: ${suggestion.title}';
}
