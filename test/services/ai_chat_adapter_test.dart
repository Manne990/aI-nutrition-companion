import 'package:ai_nutrition_companion/domain/models/ai_chat.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/meal_suggestion.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/services/adapters/ai_chat_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const configuration = AiAdapterConfiguration(
    settings: AiProviderSettings.defaults,
    tokenState: AiTokenState(
      hasToken: false,
      isSecureStorage: true,
      storageLabel: 'test secure storage',
    ),
  );
  const suggestion = MealSuggestion(
    title: 'Skyr bowl with berries',
    summary: 'Quick protein with fruit.',
    proteinGrams: 32,
    calories: 410,
    prepMinutes: 6,
    ingredientAvailability: 'All ingredients available',
    nutritionRationale: 'Closes most of today protein gap',
    source: NutritionSource.aiEstimated,
    imageAssetKey: 'fixture-skyr-bowl',
  );

  AiChatContext context() {
    final repository = InMemoryNutritionRepository();
    return AiChatContext(
      preferences: repository.userPreferences(),
      summary: repository.dailySummary(DateTime(2026, 6, 29, 15, 30)),
      configuration: configuration,
      currentSuggestion: suggestion,
    );
  }

  test('builds deterministic context summary from user and day state', () {
    final summary = buildAiChatContextSummary(context());

    expect(summary, contains('Build steady high-protein habits'));
    expect(summary, contains('2 meals today: Skyr bowl, Chicken salad'));
    expect(summary, contains('45g protein remaining'));
    expect(summary, contains('current suggestion: Skyr bowl with berries'));
    expect(summary, contains('adapter: Mock AI mock-companion-v1'));
  });

  test('routes safety boundaries before ordinary advice', () {
    expect(
      routeAiChatSafetyBoundary('Can you diagnose diabetes from this meal?'),
      AiChatSafetyBoundary.medical,
    );
    expect(
      routeAiChatSafetyBoundary('Help me stop eating and lose weight fast'),
      AiChatSafetyBoundary.eatingDisorder,
    );
    expect(
      routeAiChatSafetyBoundary('Guarantee exact calories for this photo'),
      AiChatSafetyBoundary.uncertainty,
    );
  });

  test('returns contextual protein and next-meal responses', () async {
    const adapter = MockAiChatAdapter();

    final protein = await adapter.sendMessage(
      prompt: 'How can I hit my protein goal today?',
      context: context(),
      history: const [],
    );
    final nextMeal = await adapter.sendMessage(
      prompt: 'What should I eat next?',
      context: context(),
      history: const [],
    );

    expect(protein.message, contains('45g protein left'));
    expect(protein.message, contains('Skyr bowl with berries'));
    expect(nextMeal.message, contains('Skyr bowl with berries'));
    expect(nextMeal.message, contains('32g protein'));
  });

  test('medical prompt produces safe boundary response', () async {
    const adapter = MockAiChatAdapter();

    final response = await adapter.sendMessage(
      prompt: 'Can this treat my symptoms?',
      context: context(),
      history: const [],
    );

    expect(response.safetyBoundary, AiChatSafetyBoundary.medical);
    expect(response.message, contains('cannot diagnose, treat'));
  });
}
