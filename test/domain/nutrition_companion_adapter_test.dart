import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_companion_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('companion can consume health signals without native permissions', () {
    const adapter = MockNutritionCompanionAdapter();

    final suggestions = adapter.mealSuggestions(
      healthSignals: const HealthSignalSnapshot(
        activeMinutes: 50,
        sleepHours: 7.4,
      ),
    );

    expect(
      suggestions.first.summary,
      contains('Health context shows an active day'),
    );
  });

  test('companion keeps suggestions deterministic without health signals', () {
    const adapter = MockNutritionCompanionAdapter();

    final suggestions = adapter.mealSuggestions();

    expect(suggestions.first.title, 'Skyr bowl with berries');
    expect(suggestions.first.summary, isNot(contains('Mock health signals')));
    expect(suggestions.first.summary, isNot(contains('mock health')));
  });
}
