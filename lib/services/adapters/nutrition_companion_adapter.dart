import '../../domain/models/meal_suggestion.dart';

abstract interface class NutritionCompanionAdapter {
  List<MealSuggestion> mealSuggestions();
}

class MockNutritionCompanionAdapter implements NutritionCompanionAdapter {
  const MockNutritionCompanionAdapter();

  @override
  List<MealSuggestion> mealSuggestions() => const [
    MealSuggestion(
      title: 'Skyr bowl with berries',
      summary: 'High protein, quick to make, and gentle after a lighter lunch.',
      proteinGrams: 32,
      calories: 410,
      prepMinutes: 6,
      ingredientAvailability: 'All ingredients available',
      nutritionRationale: 'Closes most of today protein gap',
      source: NutritionSource.aiEstimated,
      imageAssetKey: 'fixture-skyr-bowl',
    ),
    MealSuggestion(
      title: 'Chicken salad wrap',
      summary: 'Uses your common lunch ingredients and keeps dinner flexible.',
      proteinGrams: 38,
      calories: 520,
      prepMinutes: 12,
      ingredientAvailability: 'Chicken and greens ready',
      nutritionRationale: 'Adds lean protein without a heavy meal',
      source: NutritionSource.fallback,
      imageAssetKey: 'fixture-chicken-wrap',
    ),
    MealSuggestion(
      title: 'Banana peanut smoothie',
      summary: 'Fast energy with enough protein to bridge the afternoon.',
      proteinGrams: 24,
      calories: 360,
      prepMinutes: 4,
      ingredientAvailability: 'Likely pantry match',
      nutritionRationale: 'Useful before an evening workout',
      source: NutritionSource.aiEstimated,
      imageAssetKey: 'fixture-smoothie',
    ),
  ];
}
