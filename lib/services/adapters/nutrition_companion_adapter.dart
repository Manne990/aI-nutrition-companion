import '../../domain/models/ai_settings.dart';
import '../../domain/models/health.dart';
import '../../domain/models/meal_suggestion.dart';
import '../../domain/models/nutrition.dart';

abstract interface class NutritionCompanionAdapter {
  List<MealSuggestion> mealSuggestions({
    UserPreferences? preferences,
    HealthSignalSnapshot? healthSignals,
  });
}

class MockNutritionCompanionAdapter implements NutritionCompanionAdapter {
  const MockNutritionCompanionAdapter({this.configuration});

  final AiAdapterConfiguration? configuration;

  @override
  List<MealSuggestion> mealSuggestions({
    UserPreferences? preferences,
    HealthSignalSnapshot? healthSignals,
  }) {
    final preferenceSummary = preferences?.dietaryPreferences.isEmpty ?? true
        ? 'quick to make'
        : '${preferences!.dietaryPreferences.first}, quick to make';
    final provider = configuration?.providerLabel ?? 'Mock AI';
    final model = configuration?.settings.model ?? 'mock-companion-v1';
    final source = configuration?.shouldUseMock ?? true
        ? NutritionSource.aiEstimated
        : NutritionSource.fallback;
    final healthContext = _healthContext(healthSignals);

    return [
      MealSuggestion(
        title: 'Skyr bowl with berries',
        summary:
            'High protein, $preferenceSummary, and aligned with ${preferences?.primaryGoal.toLowerCase() ?? 'today goals'} using $provider $model.$healthContext',
        proteinGrams: 32,
        calories: 410,
        prepMinutes: 6,
        ingredientAvailability: 'All ingredients available',
        nutritionRationale: 'Closes most of today protein gap',
        source: source,
        imageAssetKey: 'fixture-skyr-bowl',
      ),
      MealSuggestion(
        title: 'Chicken salad wrap',
        summary:
            'Uses your common lunch ingredients and keeps dinner flexible.',
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
        summary:
            'Fast energy with enough protein to bridge the afternoon.$healthContext',
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
}

String _healthContext(HealthSignalSnapshot? signals) {
  if (signals == null || !signals.hasSignals) {
    return '';
  }
  if (signals.sleepHours != null && signals.sleepHours! < 7) {
    return ' Mock health signals show shorter sleep, so the suggestion stays easy to prep.';
  }
  if (signals.activeMinutes != null && signals.activeMinutes! >= 40) {
    return ' Mock health signals show an active day, so recovery protein is prioritized.';
  }
  return ' Mock health signals are available for personalization.';
}
