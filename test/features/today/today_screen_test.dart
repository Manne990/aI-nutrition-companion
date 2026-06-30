import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/domain/models/meal_suggestion.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/features/today/today_screen.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_companion_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(ListView);
  for (var attempt = 0; attempt < 12; attempt += 1) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

class _FixtureAdapter implements NutritionCompanionAdapter {
  const _FixtureAdapter(this.suggestions);

  final List<MealSuggestion> suggestions;

  @override
  List<MealSuggestion> mealSuggestions({
    UserPreferences? preferences,
    HealthSignalSnapshot? healthSignals,
  }) {
    return suggestions;
  }
}

void main() {
  final profile = OnboardingProfile(
    primaryGoal: 'Build steady high-protein habits',
    proteinGoalGrams: 110,
    dietaryPreferences: const ['high protein'],
    coachingTone: 'calm and practical',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29),
  );

  const firstSuggestion = MealSuggestion(
    title: 'Skyr bowl with berries',
    summary: 'Quick protein with fruit and a gentle texture.',
    proteinGrams: 32,
    calories: 410,
    prepMinutes: 6,
    ingredientAvailability: 'All ingredients available',
    nutritionRationale: 'Closes most of today protein gap',
    source: NutritionSource.aiEstimated,
    imageAssetKey: 'fixture-skyr-bowl',
  );

  const secondSuggestion = MealSuggestion(
    title: 'Chicken salad wrap',
    summary: 'Uses lunch ingredients and keeps dinner flexible.',
    proteinGrams: 38,
    calories: 520,
    prepMinutes: 12,
    ingredientAvailability: 'Chicken and greens ready',
    nutritionRationale: 'Adds lean protein without a heavy meal',
    source: NutritionSource.fallback,
    imageAssetKey: 'fixture-chicken-wrap',
  );

  testWidgets('renders Today recommendation, rhythm, and AI insight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
        ),
      ),
    );

    expect(find.text('Monday, June 29'), findsOneWidget);
    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text('Today focus: Build steady high-protein habits.'),
      findsOneWidget,
    );
    expect(find.text('Today rhythm'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('2h 55m ago'), findsOneWidget);
    expect(find.text('45g left'), findsOneWidget);
    expect(find.text('Daily overview'), findsOneWidget);
    expect(find.text('65 / 110 g'), findsOneWidget);
    expect(find.text('716 / 2200 kcal'), findsOneWidget);
    expect(find.text('Source gap'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

    expect(find.text('Skyr bowl with berries'), findsOneWidget);
    expect(find.text('6 min prep'), findsOneWidget);
    expect(find.text('Local afternoon option: Banana'), findsOneWidget);
    expect(find.text('Closes a large 45g protein gap'), findsOneWidget);
    expect(find.text('AI-estimated'), findsOneWidget);
    expect(
      find.textContaining('not a verified nutrition fact'),
      findsOneWidget,
    );

    await _scrollUntilVisible(
      tester,
      find.textContaining('You are about 45g short'),
    );

    expect(find.textContaining('You are about 45g short'), findsOneWidget);
  });

  testWidgets('suggestion rationale changes when no meals are confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: InMemoryNutritionRepository(seedMeals: const []),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

    expect(find.textContaining('No confirmed meals yet today'), findsOneWidget);
    expect(
      find.text('Starts today toward the 110g protein target'),
      findsOneWidget,
    );
    expect(find.text('Local afternoon option: Banana'), findsOneWidget);
  });

  testWidgets('Today shows provider provenance and source gaps', (
    tester,
  ) async {
    const openFoodFactsFood = FoodItem(
      id: 'off-yogurt',
      name: 'Barcode yogurt',
      servingDescription: '150 g cup',
      nutritionPerServing: MacroTotals(
        calories: 120,
        proteinGrams: 14,
        carbsGrams: 10,
        fatGrams: 2,
      ),
      source: SourceMetadata(
        source: NutritionSource.databaseVerified,
        label: 'Open Food Facts barcode match',
        provider: 'open-food-facts',
        confidence: 0.95,
      ),
    );
    const foodDataCentralFood = FoodItem(
      id: 'fdc-salmon',
      name: 'Salmon',
      servingDescription: '100 g cooked',
      nutritionPerServing: MacroTotals(
        calories: 208,
        proteinGrams: 22,
        carbsGrams: 0,
        fatGrams: 13,
      ),
      source: SourceMetadata(
        source: NutritionSource.databaseVerified,
        label: 'FoodData Central generic match',
        provider: 'fooddata-central',
        confidence: 0.96,
      ),
    );
    const fallbackFood = FoodItem(
      id: 'fallback-wrap',
      name: 'Local wrap',
      servingDescription: '1 wrap',
      nutritionPerServing: MacroTotals(
        calories: 360,
        proteinGrams: 20,
        carbsGrams: 42,
        fatGrams: 12,
      ),
      source: SourceMetadata(
        source: NutritionSource.fallback,
        label: 'Provider unavailable: FoodData Central missing key',
        provider: 'local-fallback',
      ),
    );
    const userConfirmedFood = FoodItem(
      id: 'manual-shake',
      name: 'Manual shake',
      servingDescription: '1 bottle',
      nutritionPerServing: MacroTotals(
        calories: 180,
        proteinGrams: 30,
        carbsGrams: 8,
        fatGrams: 3,
      ),
      source: SourceMetadata(
        source: NutritionSource.userConfirmed,
        label: 'User-confirmed',
      ),
    );
    const unknownFood = FoodItem(
      id: 'unknown-sauce',
      name: 'Unknown sauce',
      servingDescription: '1 spoonful',
      source: SourceMetadata(
        source: NutritionSource.aiEstimated,
        label: 'AI estimate',
        provider: 'mock-ai',
      ),
    );
    final repository = InMemoryNutritionRepository(
      seedMeals: [
        Meal(
          id: 'provider-meal',
          name: 'Provider plate',
          eatenAt: DateTime(2026, 6, 29, 12),
          source: NutritionSeedData.userSource,
          items: const [
            MealItem(
              id: 'off-yogurt-item',
              food: openFoodFactsFood,
              servings: 1,
              source: NutritionSeedData.userSource,
            ),
            MealItem(
              id: 'fdc-salmon-item',
              food: foodDataCentralFood,
              servings: 1,
              source: NutritionSeedData.userSource,
            ),
            MealItem(
              id: 'fallback-wrap-item',
              food: fallbackFood,
              servings: 1,
              source: NutritionSeedData.aiSource,
            ),
            MealItem(
              id: 'manual-shake-item',
              food: userConfirmedFood,
              servings: 1,
              source: NutritionSeedData.userSource,
            ),
            MealItem(
              id: 'unknown-sauce-item',
              food: unknownFood,
              servings: 1,
              source: NutritionSeedData.aiSource,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: const _FixtureAdapter([]),
          repository: repository,
          now: DateTime(2026, 6, 29, 15, 30),
        ),
      ),
    );

    expect(find.text('Source gap'), findsOneWidget);
    expect(find.text('Open Food Facts'), findsWidgets);
    expect(find.text('FoodData Central'), findsWidgets);
    expect(find.text('Local fallback'), findsWidgets);
    expect(find.text('User-confirmed'), findsWidgets);
    expect(find.text('Unknown nutrition source'), findsWidgets);
    expect(find.textContaining('provider was unavailable'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('Barcode yogurt: Open Food Facts nutrition source'),
    );

    expect(find.textContaining('Confidence 95%.'), findsOneWidget);
    expect(
      find.textContaining('Salmon: FoodData Central nutrition source'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Local wrap: Provider unavailable'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Manual shake: User-confirmed values'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Unknown sauce: Unknown nutrition source'),
      findsOneWidget,
    );
    expect(find.textContaining('not measured'), findsNothing);

    await tester.tap(find.text('Source details').first);
    await tester.pumpAndSettle();

    expect(find.text('Nutrition source details'), findsOneWidget);
    expect(find.text('Barcode yogurt'), findsWidgets);
    expect(find.text('Lookup mode:'), findsOneWidget);
    expect(find.text('Database verified'), findsOneWidget);
    expect(find.text('Provider id:'), findsOneWidget);
    expect(find.text('open-food-facts'), findsOneWidget);
    expect(find.text('Confidence:'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('suggestion actions update visible local state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Accept suggestion'));
    await tester.tap(find.text('Accept suggestion'));
    await tester.pumpAndSettle();

    expect(find.text('Accepted Skyr bowl with berries'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken salad wrap'), findsOneWidget);
    expect(find.text('Changed to Chicken salad wrap'), findsOneWidget);
    expect(
      find.textContaining('fallback context; confirm details'),
      findsOneWidget,
    );

    await _scrollUntilVisible(tester, find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Deferred for later'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Explain why'));
    await tester.tap(find.text('Explain why'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Because adds lean protein without a heavy meal and chicken and greens ready.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Today chat entry opens companion thread with context', (
    tester,
  ) async {
    final chatRepository = InMemoryAiChatRepository();

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          chatRepository: chatRepository,
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Ask the companion'));

    final chatField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Ask what to eat, why, or how to adjust',
    );
    await tester.enterText(chatField, 'How can I hit my protein goal today?');
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(find.text('AI Companion'), findsOneWidget);
    expect(find.text('How can I hit my protein goal today?'), findsOneWidget);
    expect(find.textContaining('45g protein left'), findsWidgets);
    expect(find.textContaining('Skyr bowl with berries'), findsWidgets);

    final messages = await chatRepository.loadMessages();
    expect(messages, hasLength(2));
    expect(messages.first.content, 'How can I hit my protein goal today?');
    expect(messages.last.content, contains('45g protein left'));
  });

  testWidgets('empty fixture data renders a graceful Today state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: const _FixtureAdapter([]),
          repository: InMemoryNutritionRepository(seedMeals: const []),
        ),
      ),
    );

    expect(find.text('No meals yet'), findsOneWidget);
    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.text('0 / 110 g'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('No meal suggestion ready'));

    expect(find.text('No meal suggestion ready'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('No meals logged yet today'),
    );

    expect(find.textContaining('No meals logged yet today'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('I do not have a suggestion yet'),
    );

    expect(
      find.textContaining('I do not have a suggestion yet'),
      findsOneWidget,
    );
  });

  testWidgets('weight entry persists locally and updates trend display', (
    tester,
  ) async {
    final repository = InMemoryNutritionRepository(
      seedWeightEntries: [
        WeightEntry(
          id: 'yesterday',
          recordedAt: DateTime(2026, 6, 28, 7),
          weightKg: 82.4,
          source: NutritionSeedData.userSource,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: repository,
          now: DateTime(2026, 6, 29, 15, 30),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Add weight'));
    await tester.enterText(find.byType(TextField), '81.9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.weightEntries(), hasLength(2));
    expect(find.textContaining('81.9 kg'), findsOneWidget);
    expect(find.textContaining('Down 0.5 kg'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Weight saved. Trend updated for today.'),
    );

    expect(find.text('Weight saved. Trend updated for today.'), findsOneWidget);
  });

  testWidgets('quick log confirmation adds a snack to today', (tester) async {
    final repository = InMemoryNutritionRepository();

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: repository,
          now: DateTime(2026, 6, 29, 16),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Quick Log'));

    expect(
      find.text('Afternoon suggestions from your meal rhythm.'),
      findsOneWidget,
    );
    expect(find.text('Banana snack'), findsOneWidget);

    await tester.tap(find.text('Log').first);
    await tester.pumpAndSettle();

    expect(repository.meals(), hasLength(3));
    expect(repository.meals().last.name, 'Banana snack');
    expect(repository.meals().last.source.label, 'Quick Log confirmed meal');

    await _scrollUntilVisible(
      tester,
      find.text('Banana snack added from Quick Log.'),
    );

    expect(find.text('Banana snack added from Quick Log.'), findsOneWidget);
  });

  testWidgets('completed day state keeps guidance actionable', (tester) async {
    final repository = InMemoryNutritionRepository(
      seedMeals: [NutritionSeedData.meals.first],
      seedGoal: const NutritionGoal(
        proteinGrams: 20,
        calories: 180,
        carbsGrams: 20,
        fatGrams: 1,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: repository,
        ),
      ),
    );

    expect(find.text('23 / 20 g'), findsWidgets);
    expect(find.textContaining('Protein goal met'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('Your protein target is covered'),
    );

    expect(
      find.textContaining('Your protein target is covered'),
      findsOneWidget,
    );
    await _scrollUntilVisible(
      tester,
      find.text('Protein target is covered; choose for appetite and routine'),
    );

    expect(
      find.text('Protein target is covered; choose for appetite and routine'),
      findsOneWidget,
    );
  });

  testWidgets('Today fits small and large mobile constraints', (tester) async {
    for (final size in const [Size(320, 720), Size(430, 932)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        _wrap(
          TodayScreen(
            profile: profile,
            adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('What should I eat next?'), findsOneWidget);

      await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

      expect(find.text('Skyr bowl with berries'), findsOneWidget);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
