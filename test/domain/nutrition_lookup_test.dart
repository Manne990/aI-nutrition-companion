import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/domain/services/nutrition_lookup_service.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_lookup_adapters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nutrition lookup providers', () {
    test('local lookup returns verified database records by name', () async {
      final provider = LocalNutritionLookupProvider(
        foods: NutritionSeedData.foods,
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'plain skyr'),
      );

      expect(result.status, NutritionLookupStatus.verified);
      expect(result.food?.source.source, NutritionSource.databaseVerified);
      expect(result.food?.nutritionPerServing?.proteinGrams, 22);
      expect(result.providerName, 'local-fallback');
    });

    test('local lookup keeps fallback records explicit', () async {
      final provider = LocalNutritionLookupProvider(
        foods: NutritionSeedData.foods,
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'chicken salad'),
      );

      expect(result.status, NutritionLookupStatus.fallback);
      expect(result.food?.source.source, NutritionSource.fallback);
      expect(result.message, contains('fallback'));
    });

    test(
      'Open Food Facts adapter is barcode-ready and deterministic',
      () async {
        const packagedSkyr = FoodItem(
          id: 'off-skyr',
          name: 'Packaged skyr',
          servingDescription: '170 g cup',
          nutritionPerServing: MacroTotals(
            calories: 120,
            proteinGrams: 18,
            carbsGrams: 8,
            fatGrams: 0.2,
          ),
          source: SourceMetadata(
            source: NutritionSource.databaseVerified,
            label: 'Open Food Facts',
            provider: 'open-food-facts',
            confidence: 0.98,
          ),
        );
        const provider = OpenFoodFactsNutritionProvider(
          packagedProducts: {'1234567890123': packagedSkyr},
        );

        final result = await provider.lookup(
          const NutritionLookupQuery(
            foodName: 'skyr',
            barcode: '1234567890123',
          ),
        );

        expect(result.status, NutritionLookupStatus.verified);
        expect(result.food?.id, 'off-skyr');
        expect(result.food?.source.provider, 'open-food-facts');
      },
    );

    test(
      'FoodData Central adapter reports missing API key explicitly',
      () async {
        const provider = FoodDataCentralNutritionProvider(apiKey: null);

        final result = await provider.lookup(
          const NutritionLookupQuery(foodName: 'salmon'),
        );

        expect(result.status, NutritionLookupStatus.missingApiKey);
        expect(result.isProviderUnavailable, isTrue);
        expect(result.message, contains('FOODDATA_CENTRAL_API_KEY'));
      },
    );
  });

  group('NutritionEnrichmentService', () {
    test('enriches AI-estimated foods with verified records', () async {
      final service = NutritionEnrichmentService(
        providers: const [
          FoodDataCentralNutritionProvider(
            apiKey: 'test-key',
            foodsByName: {
              'rolled oats': FoodItem(
                id: 'fdc-oats',
                name: 'Rolled oats',
                servingDescription: '50 g dry oats',
                nutritionPerServing: MacroTotals(
                  calories: 185,
                  proteinGrams: 6.5,
                  carbsGrams: 30,
                  fatGrams: 3.5,
                ),
                source: SourceMetadata(
                  source: NutritionSource.databaseVerified,
                  label: 'FoodData Central',
                  provider: 'fooddata-central',
                  confidence: 0.96,
                ),
              ),
            },
          ),
        ],
        fallbackProvider: LocalNutritionLookupProvider(
          foods: NutritionSeedData.foods,
        ),
      );
      const aiItem = MealItem(
        id: 'ai-oats',
        food: FoodItem(
          id: 'ai-oats-food',
          name: 'Rolled oats',
          servingDescription: 'AI-estimated bowl',
          source: NutritionSeedData.aiSource,
        ),
        servings: 1.2,
        source: NutritionSeedData.aiSource,
      );

      final enrichment = await service.enrichMealItems([aiItem]);
      final enriched = enrichment.items.single;

      expect(
        enrichment.lookupResults.single.status,
        NutritionLookupStatus.verified,
      );
      expect(enriched.source.source, NutritionSource.aiEstimated);
      expect(enriched.food.source.source, NutritionSource.databaseVerified);
      expect(enriched.macroTotals?.calories, 222);
      expect(enrichment.knownMacroTotals.proteinGrams, closeTo(7.8, 0.001));
      expect(enrichment.hasUnverifiedAiNutrition, isFalse);
    });

    test(
      'falls back locally when configured providers are unavailable',
      () async {
        final service = NutritionEnrichmentService(
          providers: const [FoodDataCentralNutritionProvider(apiKey: null)],
          fallbackProvider: LocalNutritionLookupProvider(
            foods: NutritionSeedData.foods,
          ),
        );
        const aiItem = MealItem(
          id: 'ai-banana',
          food: FoodItem(
            id: 'ai-banana-food',
            name: 'Banana',
            servingDescription: 'AI-estimated piece',
            source: NutritionSeedData.aiSource,
          ),
          servings: 1,
          source: NutritionSeedData.aiSource,
        );

        final enrichment = await service.enrichMealItems([aiItem]);
        final enriched = enrichment.items.single;

        expect(
          enrichment.lookupResults.single.status,
          NutritionLookupStatus.fallback,
        );
        expect(
          enrichment.lookupResults.single.message,
          contains('FOODDATA_CENTRAL_API_KEY'),
        );
        expect(enriched.source.source, NutritionSource.aiEstimated);
        expect(enriched.food.source.source, NutritionSource.fallback);
        expect(enrichment.hasFallbackNutrition, isTrue);
        expect(enrichment.hasUnverifiedAiNutrition, isTrue);
      },
    );

    test('keeps unknown AI nutrition unverified and missing', () async {
      final repository = InMemoryNutritionRepository();
      const aiItem = MealItem(
        id: 'ai-mystery',
        food: FoodItem(
          id: 'ai-mystery-food',
          name: 'Mystery stew',
          servingDescription: 'AI-estimated bowl',
          source: NutritionSeedData.aiSource,
        ),
        servings: 1,
        source: NutritionSeedData.aiSource,
      );

      final enrichment = await repository.enrichMealItems([aiItem]);

      expect(enrichment.items.single, same(aiItem));
      expect(enrichment.itemsWithMissingNutrition, 1);
      expect(
        enrichment.lookupResults.single.status,
        NutritionLookupStatus.missingApiKey,
      );
      expect(enrichment.hasUnverifiedAiNutrition, isTrue);
    });

    test('repository can enrich a meal estimate before confirmation', () async {
      final repository = InMemoryNutritionRepository();
      final estimate = MealEstimate(
        id: 'estimate-1',
        estimatedAt: DateTime(2026, 6, 29, 18),
        source: NutritionSeedData.aiSource,
        items: const [
          MealItem(
            id: 'estimate-skyr',
            food: FoodItem(
              id: 'ai-skyr',
              name: 'Plain skyr',
              servingDescription: 'AI-estimated bowl',
              source: NutritionSeedData.aiSource,
            ),
            servings: 1,
            source: NutritionSeedData.aiSource,
          ),
        ],
      );

      final enriched = await repository.enrichMealEstimate(estimate);
      final confirmed = enriched.confirm(
        mealId: 'meal-1',
        name: 'Photo meal',
        eatenAt: DateTime(2026, 6, 29, 18, 5),
      );

      expect(enriched.items.single.food.source.isVerified, isTrue);
      expect(confirmed.knownMacroTotals.proteinGrams, 22);
      expect(confirmed.source.source, NutritionSource.userConfirmed);
    });
  });
}
