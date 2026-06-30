import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('buildDailySummary', () {
    test('aggregates known macros and keeps missing nutrition explicit', () {
      final repository = InMemoryNutritionRepository();

      final summary = repository.dailySummary(DateTime(2026, 6, 29, 18));

      expect(summary.meals, hasLength(2));
      expect(summary.knownMacroTotals.calories, 716);
      expect(summary.knownMacroTotals.proteinGrams, 64.6);
      expect(summary.knownMacroTotals.carbsGrams, 61);
      expect(summary.knownMacroTotals.fatGrams, 22.7);
      expect(summary.itemsWithMissingNutrition, 1);
      expect(summary.hasMissingNutrition, isTrue);
      expect(summary.proteinRemainingGrams, closeTo(45.4, 0.001));
      expect(summary.calorieRemaining, 1484);
      expect(summary.proteinProgress, closeTo(0.587, 0.001));
      expect(summary.calorieProgress, closeTo(0.325, 0.001));
      expect(summary.latestWeightEntry?.weightKg, 82.4);
    });

    test('filters meals by day and sorts them by time', () {
      final morning = Meal(
        id: 'morning',
        name: 'Morning meal',
        eatenAt: DateTime(2026, 6, 30, 8),
        items: const [],
        source: NutritionSeedData.userSource,
      );
      final evening = Meal(
        id: 'evening',
        name: 'Evening meal',
        eatenAt: DateTime(2026, 6, 30, 20),
        items: const [],
        source: NutritionSeedData.userSource,
      );
      final repository = InMemoryNutritionRepository(
        seedMeals: [evening, morning, ...NutritionSeedData.meals],
      );

      final summary = repository.dailySummary(DateTime(2026, 6, 30));

      expect(summary.meals.map((meal) => meal.id), ['morning', 'evening']);
    });

    test('reports weight trend from the latest two available entries', () {
      final repository = InMemoryNutritionRepository(
        seedWeightEntries: [
          WeightEntry(
            id: 'yesterday',
            recordedAt: DateTime(2026, 6, 28, 7),
            weightKg: 82.9,
            source: NutritionSeedData.userSource,
          ),
          WeightEntry(
            id: 'today',
            recordedAt: DateTime(2026, 6, 29, 7),
            weightKg: 82.4,
            source: NutritionSeedData.userSource,
          ),
        ],
      );

      final summary = repository.dailySummary(DateTime(2026, 6, 29, 18));

      expect(summary.latestWeightEntry?.id, 'today');
      expect(summary.previousWeightEntry?.id, 'yesterday');
      expect(summary.weightDeltaKg, closeTo(-0.5, 0.001));
    });

    test('caps completed-day progress at one', () {
      final repository = InMemoryNutritionRepository(
        seedGoal: const NutritionGoal(
          proteinGrams: 30,
          calories: 500,
          carbsGrams: 40,
          fatGrams: 15,
        ),
      );

      final summary = repository.dailySummary(DateTime(2026, 6, 29));

      expect(summary.proteinRemainingGrams, 0);
      expect(summary.proteinProgress, 1);
      expect(summary.calorieProgress, 1);
    });
  });

  group('MealItem.userCorrected', () {
    test('overrides an AI estimate without losing original provenance', () {
      const estimatedFood = FoodItem(
        id: 'estimate-oats',
        name: 'Oats, estimated',
        servingDescription: 'AI portion',
        nutritionPerServing: MacroTotals(
          calories: 190,
          proteinGrams: 6,
          carbsGrams: 32,
          fatGrams: 4,
        ),
        source: NutritionSeedData.aiSource,
      );
      const verifiedFood = FoodItem(
        id: 'verified-oats',
        name: 'Rolled oats',
        servingDescription: '50 g',
        nutritionPerServing: MacroTotals(
          calories: 185,
          proteinGrams: 6.5,
          carbsGrams: 30,
          fatGrams: 3.5,
        ),
        source: NutritionSeedData.databaseSource,
      );
      const estimate = MealItem(
        id: 'estimate-item',
        food: estimatedFood,
        servings: 1.2,
        source: NutritionSeedData.aiSource,
      );

      final corrected = estimate.userCorrected(
        id: 'corrected-item',
        food: verifiedFood,
        servings: 1,
        userNote: 'Corrected from photo estimate',
      );

      expect(corrected.source.source, NutritionSource.userConfirmed);
      expect(corrected.food.source.source, NutritionSource.databaseVerified);
      expect(corrected.replacesEstimateId, 'estimate-item');
      expect(corrected.macroTotals?.calories, 185);
      expect(estimate.source.source, NutritionSource.aiEstimated);
      expect(estimate.macroTotals?.calories, 228);
    });
  });

  group('InMemoryNutritionRepository', () {
    test('saveMeal replaces by id and updates daily summary', () {
      final repository = InMemoryNutritionRepository(seedMeals: const []);
      final meal = Meal(
        id: 'snack',
        name: 'Protein snack',
        eatenAt: DateTime(2026, 6, 29, 16),
        items: [
          MealItem(
            id: 'snack-skyr',
            food: NutritionSeedData.foods.first,
            servings: 0.5,
            source: NutritionSeedData.userSource,
          ),
        ],
        source: NutritionSeedData.userSource,
      );

      repository.saveMeal(meal);
      repository.saveMeal(
        Meal(
          id: 'snack',
          name: 'Protein snack corrected',
          eatenAt: DateTime(2026, 6, 29, 16, 5),
          items: [
            MealItem(
              id: 'snack-skyr-corrected',
              food: NutritionSeedData.foods.first,
              servings: 1,
              source: NutritionSeedData.userSource,
            ),
          ],
          source: NutritionSeedData.userSource,
        ),
      );

      final summary = repository.dailySummary(DateTime(2026, 6, 29));

      expect(summary.meals, hasLength(1));
      expect(summary.meals.single.name, 'Protein snack corrected');
      expect(summary.knownMacroTotals.proteinGrams, 22);
    });

    test('quickLogSuggestions prefer known time-window history', () {
      final repository = InMemoryNutritionRepository();

      final suggestions = repository.quickLogSuggestions(
        DateTime(2026, 6, 29, 12, 45),
      );

      expect(suggestions.first.mealName, 'Chicken salad');
      expect(suggestions.first.timeWindowLabel, 'Midday');
      expect(
        suggestions.first.reason,
        contains('Usually logged around midday'),
      );
      expect(suggestions.first.availability, IngredientAvailability.runningLow);
    });

    test(
      'quickLogSuggestions use deterministic defaults for sparse windows',
      () {
        final repository = InMemoryNutritionRepository(seedMeals: const []);

        final suggestions = repository.quickLogSuggestions(
          DateTime(2026, 6, 29, 23, 15),
        );

        expect(suggestions.map((suggestion) => suggestion.mealName), [
          'Skyr bowl',
          'Banana snack',
        ]);
        expect(suggestions.first.timeWindowLabel, 'Late');
        expect(suggestions.first.reason, 'Light option for a late check-in');
      },
    );

    test('confirmQuickLogSuggestion persists a user-confirmed meal', () {
      final repository = InMemoryNutritionRepository(seedMeals: const []);
      final suggestion = repository
          .quickLogSuggestions(DateTime(2026, 6, 29, 16))
          .first;

      final meal = repository.confirmQuickLogSuggestion(
        suggestion,
        eatenAt: DateTime(2026, 6, 29, 16, 5),
      );

      expect(meal.source.label, 'Quick Log confirmed meal');
      expect(meal.items.single.source.label, 'Quick Log confirmed');
      expect(repository.meals(), hasLength(1));
      expect(
        repository.dailySummary(DateTime(2026, 6, 29)).meals.single.id,
        meal.id,
      );
    });

    test('favorite meals and kitchen inventory derive from local data', () {
      final repository = InMemoryNutritionRepository();

      final favorites = repository.favoriteMeals();
      final inventory = repository.kitchenInventory();

      expect(favorites.map((favorite) => favorite.name), [
        'Chicken salad',
        'Skyr bowl',
      ]);
      expect(
        inventory
            .firstWhere((item) => item.food.id == 'food-skyr')
            .availability,
        IngredientAvailability.available,
      );
      expect(
        inventory
            .firstWhere((item) => item.food.id == 'food-chicken-salad')
            .availability,
        IngredientAvailability.runningLow,
      );
    });
  });

  group('SharedPreferencesNutritionRepository', () {
    test('falls back to seed data when persisted JSON is corrupt', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesNutritionRepository.stateKey: '{not json',
      });
      final preferences = await SharedPreferences.getInstance();

      final repository = SharedPreferencesNutritionRepository(preferences);

      expect(repository.meals().map((meal) => meal.id), [
        'meal-breakfast',
        'meal-lunch',
      ]);
      expect(repository.weightEntries().single.id, 'weight-start');
    });

    test(
      'falls back to seed data when persisted state has wrong shape',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesNutritionRepository.stateKey:
              '{"version":1,"meals":"bad","weightEntries":[]}',
        });
        final preferences = await SharedPreferences.getInstance();

        final repository = SharedPreferencesNutritionRepository(preferences);

        expect(repository.meals(), hasLength(2));
        expect(repository.weightEntries(), hasLength(1));
      },
    );

    test(
      'persists quick logs, photo meals, and weights after recreation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final repository = SharedPreferencesNutritionRepository(
          preferences,
          seedMeals: const [],
          seedWeightEntries: const [],
        );

        final suggestion = repository
            .quickLogSuggestions(DateTime(2026, 6, 29, 16))
            .first;
        final quickLog = repository.confirmQuickLogSuggestion(
          suggestion,
          eatenAt: DateTime(2026, 6, 29, 16, 5),
        );
        final photoMeal = Meal(
          id: 'photo-dinner',
          name: 'Photo dinner',
          eatenAt: DateTime(2026, 6, 29, 19),
          items: [
            MealItem(
              id: 'photo-dinner-item',
              food: NutritionSeedData.foods.first,
              servings: 1,
              source: NutritionSeedData.aiSource,
            ),
          ],
          source: NutritionSeedData.userSource,
          photoPath: '/tmp/photo-dinner.jpg',
        );
        repository.saveMeal(photoMeal);
        repository.saveWeightEntry(
          WeightEntry(
            id: 'weight-evening',
            recordedAt: DateTime(2026, 6, 29, 21),
            weightKg: 81.9,
            source: NutritionSeedData.userSource,
          ),
        );
        await repository.flushPendingWrites();

        final recreated = SharedPreferencesNutritionRepository(
          preferences,
          seedMeals: const [],
          seedWeightEntries: const [],
        );

        expect(recreated.meals().map((meal) => meal.id), [
          quickLog.id,
          photoMeal.id,
        ]);
        expect(recreated.meals().last.photoPath, '/tmp/photo-dinner.jpg');
        expect(recreated.weightEntries().single.weightKg, 81.9);
        expect(
          recreated
              .dailySummary(DateTime(2026, 6, 29))
              .meals
              .map((meal) => meal.name),
          ['Banana snack', 'Photo dinner'],
        );
      },
    );

    test('drops malformed persisted records without crashing', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final validRepository = SharedPreferencesNutritionRepository(
        preferences,
        seedMeals: const [],
        seedWeightEntries: const [],
      );
      final meal = Meal(
        id: 'valid-meal',
        name: 'Valid meal',
        eatenAt: DateTime(2026, 6, 29, 12),
        items: [
          MealItem(
            id: 'valid-item',
            food: NutritionSeedData.foods.first,
            servings: 1,
            source: NutritionSeedData.userSource,
          ),
        ],
        source: NutritionSeedData.userSource,
      );
      validRepository.saveMeal(meal);
      await validRepository.flushPendingWrites();

      final stored = preferences.getString(
        SharedPreferencesNutritionRepository.stateKey,
      );
      await preferences.setString(
        SharedPreferencesNutritionRepository.stateKey,
        stored!.replaceFirst(
          '"items":[{',
          '"items":["bad-item",{"id":"","food":null},{',
        ),
      );

      final recreated = SharedPreferencesNutritionRepository(
        preferences,
        seedMeals: const [],
        seedWeightEntries: const [],
      );

      expect(recreated.meals(), hasLength(1));
      expect(recreated.meals().single.items, hasLength(1));
      expect(recreated.meals().single.items.single.id, 'valid-item');
    });

    test('clears persisted meals and daily progress for local reset', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesNutritionRepository(
        preferences,
        seedMeals: const [],
        seedWeightEntries: const [],
      );
      final meal = Meal(
        id: 'reset-meal',
        name: 'Reset meal',
        eatenAt: DateTime(2026, 6, 29, 12),
        items: [
          MealItem(
            id: 'reset-item',
            food: NutritionSeedData.foods.first,
            servings: 1,
            source: NutritionSeedData.userSource,
          ),
        ],
        source: NutritionSeedData.userSource,
      );
      repository.saveMeal(meal);
      repository.saveWeightEntry(
        WeightEntry(
          id: 'reset-weight',
          recordedAt: DateTime(2026, 6, 29, 7),
          weightKg: 82,
          source: NutritionSeedData.userSource,
        ),
      );
      await repository.flushPendingWrites();

      await repository.clearLocalProgress();

      expect(repository.meals(), isEmpty);
      expect(repository.weightEntries(), isEmpty);
      expect(
        preferences.containsKey(SharedPreferencesNutritionRepository.stateKey),
        isFalse,
      );

      final recreated = SharedPreferencesNutritionRepository(
        preferences,
        seedMeals: const [],
        seedWeightEntries: const [],
      );
      final summary = recreated.dailySummary(DateTime(2026, 6, 29));

      expect(recreated.meals(), isEmpty);
      expect(recreated.weightEntries(), isEmpty);
      expect(summary.meals, isEmpty);
      expect(summary.knownMacroTotals.calories, 0);
    });
  });
}
