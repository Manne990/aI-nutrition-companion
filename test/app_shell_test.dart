import 'package:ai_nutrition_companion/app/ai_nutrition_companion_app.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/health_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/onboarding_repository.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_lookup_adapters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OnboardingProfile _profile() {
  return OnboardingProfile(
    primaryGoal: 'Build steady high-protein habits',
    proteinGoalGrams: 110,
    dietaryPreferences: const ['high protein'],
    coachingTone: 'calm and practical',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29),
  );
}

Future<void> _searchGenericFood(WidgetTester tester, String foodName) async {
  await _scrollUntilVisible(tester, _textFieldWithLabel('Food name'));
  await tester.enterText(_textFieldWithLabel('Food name'), foodName);
  await _scrollUntilVisible(tester, find.text('Search generic food'));
  await tester.tap(find.text('Search generic food'));
  await tester.pumpAndSettle();
}

class _RuntimeFoodDataCentralSearchClient
    implements FoodDataCentralSearchClient {
  final apiKeys = <String>[];
  final queries = <String>[];

  @override
  Future<FoodDataCentralSearchResponse> searchFoods({
    required String query,
    required String apiKey,
  }) async {
    apiKeys.add(apiKey);
    queries.add(query);
    return FoodDataCentralSearchResponse.fromJson({
      'foods': [
        {
          'fdcId': '${apiKeys.length}${query.length}',
          'description': '$query verified',
          'servingSize': 100,
          'servingSizeUnit': 'g',
          'foodNutrients': [
            {'nutrientId': 1008, 'nutrientName': 'Energy', 'value': 180},
            {'nutrientId': 1003, 'nutrientName': 'Protein', 'value': 20},
            {'nutrientId': 1005, 'nutrientName': 'Carbohydrate', 'value': 3},
            {
              'nutrientId': 1004,
              'nutrientName': 'Total lipid (fat)',
              'value': 9,
            },
          ],
        },
      ],
    });
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  InMemoryOnboardingRepository? repository,
  AiSettingsRepository? aiSettingsRepository,
  NutritionRepository? nutritionRepository,
  FoodDataCentralSearchClient? foodDataCentralSearchClient,
  bool useDefaultNutritionRepository = false,
}) async {
  await tester.pumpWidget(
    AiNutritionCompanionApp(
      onboardingRepository:
          repository ?? InMemoryOnboardingRepository(_profile()),
      aiSettingsRepository:
          aiSettingsRepository ?? InMemoryAiSettingsRepository(),
      authRepository: InMemoryAuthRepository(),
      healthRepository: InMemoryHealthRepository(),
      aiChatRepository: InMemoryAiChatRepository(),
      nutritionRepository: useDefaultNutritionRepository
          ? nutritionRepository
          : nutritionRepository ?? InMemoryNutritionRepository(),
      foodDataCentralSearchClient: foodDataCentralSearchClient,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
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

void main() {
  testWidgets('returning user sees Today and bottom navigation', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(find.text('Daily overview'), findsOneWidget);
    expect(find.text('110g protein goal'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

    expect(find.text('Skyr bowl with berries'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between V1 sections', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('AI provider'), findsOneWidget);
  });

  testWidgets('Today and Kitchen share saved nutrition state', (tester) async {
    final nutritionRepository = InMemoryNutritionRepository();

    await _pumpApp(tester, nutritionRepository: nutritionRepository);

    await _scrollUntilVisible(tester, find.text('Banana snack'));
    final bananaSuggestion = find.ancestor(
      of: find.text('Banana snack'),
      matching: find.byType(DecoratedBox),
    );
    final bananaLogButton = find.descendant(
      of: bananaSuggestion,
      matching: find.widgetWithText(FilledButton, 'Log'),
    );
    await tester.ensureVisible(bananaLogButton);
    await tester.pumpAndSettle();

    await tester.tap(bananaLogButton);
    await tester.pumpAndSettle();

    expect(nutritionRepository.meals().last.name, 'Banana snack');

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);
    expect(find.text('Banana snack'), findsOneWidget);
  });

  testWidgets('Today and Kitchen restore persisted nutrition progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesNutritionRepository(
      preferences,
      seedMeals: const [],
      seedWeightEntries: const [],
    );
    repository.saveMeal(
      Meal(
        id: 'persisted-banana',
        name: 'Persisted banana snack',
        eatenAt: DateTime(2026, 6, 29, 15),
        items: [
          MealItem(
            id: 'persisted-banana-item',
            food: NutritionSeedData.foods.firstWhere(
              (food) => food.id == 'food-banana',
            ),
            servings: 1,
            source: NutritionSeedData.userSource,
          ),
        ],
        source: NutritionSeedData.userSource,
      ),
    );
    await repository.flushPendingWrites();

    await _pumpApp(tester, useDefaultNutritionRepository: true);

    await _scrollUntilVisible(tester, find.text('Persisted banana snack'));
    expect(find.text('Persisted banana snack'), findsOneWidget);
    expect(find.text('105 kcal | 1g protein'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);
    expect(find.text('Persisted banana snack'), findsOneWidget);
  });

  testWidgets(
    'FoodData Central key save change and delete refresh runtime lookup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final aiSettingsRepository = InMemoryAiSettingsRepository();
      final foodDataCentralClient = _RuntimeFoodDataCentralSearchClient();

      await _pumpApp(
        tester,
        aiSettingsRepository: aiSettingsRepository,
        useDefaultNutritionRepository: true,
        foodDataCentralSearchClient: foodDataCentralClient,
      );

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        _textFieldWithLabel('FoodData Central API key'),
      );
      await tester.enterText(
        _textFieldWithLabel('FoodData Central API key'),
        'first-user-key',
      );
      await _scrollUntilVisible(tester, find.text('Save FoodData Central key'));
      await tester.tap(find.text('Save FoodData Central key'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
      await tester.pumpAndSettle();
      await _searchGenericFood(tester, 'salmon');

      expect(foodDataCentralClient.apiKeys, ['first-user-key']);
      expect(find.text('salmon verified'), findsOneWidget);
      expect(
        find.text('Matched FoodData Central search nutrition.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        _textFieldWithLabel('FoodData Central API key'),
      );
      await tester.enterText(
        _textFieldWithLabel('FoodData Central API key'),
        'second-user-key',
      );
      await _scrollUntilVisible(
        tester,
        find.text('Update FoodData Central key'),
      );
      await tester.tap(find.text('Update FoodData Central key'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
      await tester.pumpAndSettle();
      await _searchGenericFood(tester, 'oats');

      expect(foodDataCentralClient.apiKeys, [
        'first-user-key',
        'second-user-key',
      ]);
      expect(find.text('oats verified'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.text('Delete FoodData Central key'),
      );
      await tester.tap(find.text('Delete FoodData Central key'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
      await tester.pumpAndSettle();
      await _searchGenericFood(tester, 'avocado');

      expect(foodDataCentralClient.apiKeys, [
        'first-user-key',
        'second-user-key',
      ]);
      expect(find.text('FoodData Central key needed'), findsOneWidget);
      expect(
        find.text(
          'Add a FoodData Central API key to use generic food search. No app-owned key is bundled.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('first-run user can skip optional steps and complete consent', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository();

    await _pumpApp(tester, repository: repository);

    expect(find.text('Set your direction'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Food boundaries'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Targets and tone'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Consent boundaries'), findsOneWidget);
    expect(find.text('Start Today'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.tap(find.byType(CheckboxListTile).at(2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Today'));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect((await repository.loadProfile())?.hasRequiredConsent, isTrue);
  });

  testWidgets(
    'reset onboarding clears local profile for tests and development',
    (tester) async {
      final repository = InMemoryOnboardingRepository(_profile());

      await _pumpApp(tester, repository: repository);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(tester, find.text('Reset onboarding'));
      await tester.tap(find.text('Reset onboarding'));
      await tester.pumpAndSettle();

      expect(await repository.loadProfile(), isNull);
      expect(find.text('Set your direction'), findsOneWidget);
    },
  );
}
