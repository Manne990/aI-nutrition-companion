import '../../domain/models/meal_suggestion.dart';

abstract interface class NutritionCompanionAdapter {
  MealSuggestion nextMealSuggestion();
}

class MockNutritionCompanionAdapter implements NutritionCompanionAdapter {
  const MockNutritionCompanionAdapter();

  @override
  MealSuggestion nextMealSuggestion() {
    return const MealSuggestion(
      title: 'Skyr bowl with berries',
      summary: 'High protein, quick to make, and gentle after a light lunch.',
      proteinGrams: 32,
      calories: 410,
      source: NutritionSource.aiEstimated,
    );
  }
}
