import '../../domain/models/nutrition.dart';
import '../photo/photo_meal_source.dart';

abstract interface class MealRecognitionAdapter {
  Future<MealEstimate> estimateMealFromPhoto(PhotoMealCapture capture);
}

class MealRecognitionException implements Exception {
  const MealRecognitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockMealRecognitionAdapter implements MealRecognitionAdapter {
  const MockMealRecognitionAdapter({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<MealEstimate> estimateMealFromPhoto(PhotoMealCapture capture) async {
    if (shouldFail || capture.path.contains('mock-failure')) {
      throw const MealRecognitionException(
        'Mock recognition failed. The photo log can be retried or entered manually.',
      );
    }

    final capturedAt = DateTime(2026, 6, 29, 17, 45);
    final source = SourceMetadata(
      source: NutritionSource.aiEstimated,
      label: 'AI photo estimate',
      provider: 'mock-photo-ai',
      confidence: capture.mode == PhotoMealCaptureMode.camera ? 0.78 : 0.74,
      observedAt: capturedAt,
    );

    return MealEstimate(
      id: 'mock-photo-estimate-${capture.mode.name}',
      estimatedAt: capturedAt,
      photoPath: capture.path,
      source: source,
      items: [
        MealItem(
          id: 'estimate-chicken-bowl',
          food: FoodItem(
            id: 'food-estimate-chicken-bowl',
            name: 'Chicken grain bowl',
            servingDescription: '1 bowl',
            nutritionPerServing: const MacroTotals(
              calories: 610,
              proteinGrams: 45,
              carbsGrams: 58,
              fatGrams: 21,
            ),
            source: source,
          ),
          servings: 1,
          source: source,
        ),
        MealItem(
          id: 'estimate-dressing',
          food: FoodItem(
            id: 'food-estimate-dressing',
            name: 'Creamy dressing',
            servingDescription: '2 tbsp estimate',
            nutritionPerServing: const MacroTotals(
              calories: 120,
              proteinGrams: 1,
              carbsGrams: 3,
              fatGrams: 11,
            ),
            source: source.copyWith(confidence: 0.56),
          ),
          servings: 1,
          source: source.copyWith(confidence: 0.56),
        ),
      ],
    );
  }
}
