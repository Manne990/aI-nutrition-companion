import 'dart:async';

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

    test('Open Food Facts adapter parses barcode product response', () async {
      final transport = _FakeOpenFoodFactsTransport(
        response: const OpenFoodFactsTransportResponse(
          statusCode: 200,
          body: '''
{
  "status": 1,
  "product": {
    "product_name": "Packaged skyr",
    "serving_size": "170 g cup",
    "nutriments": {
      "energy-kcal_serving": 120,
      "proteins_serving": "18",
      "carbohydrates_serving": 8,
      "fat_serving": 0.2
    }
  }
}
''',
        ),
      );
      final provider = OpenFoodFactsNutritionProvider(transport: transport);

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'skyr', barcode: '1234567890123'),
      );

      expect(result.status, NutritionLookupStatus.verified);
      expect(result.food?.id, 'off-1234567890123');
      expect(result.food?.name, 'Packaged skyr');
      expect(result.food?.servingDescription, '170 g cup');
      expect(result.food?.nutritionPerServing?.calories, 120);
      expect(result.food?.nutritionPerServing?.proteinGrams, 18);
      expect(result.food?.nutritionPerServing?.carbsGrams, 8);
      expect(result.food?.nutritionPerServing?.fatGrams, 0.2);
      expect(result.food?.source.source, NutritionSource.databaseVerified);
      expect(result.food?.source.provider, 'open-food-facts');
      expect(result.providerName, 'open-food-facts');
      expect(transport.lastUri?.path, '/api/v3/product/1234567890123.json');
      expect(
        transport.lastHeaders['user-agent'],
        contains('AI Nutrition Companion'),
      );
      expect(transport.lastHeaders['accept'], 'application/json');
    });

    test('Open Food Facts adapter reports barcode not found', () async {
      final provider = OpenFoodFactsNutritionProvider(
        transport: _FakeOpenFoodFactsTransport(
          response: const OpenFoodFactsTransportResponse(
            statusCode: 200,
            body: '{"status":0,"status_verbose":"product not found"}',
          ),
        ),
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'unknown', barcode: '0000000000'),
      );

      expect(result.status, NutritionLookupStatus.notFound);
      expect(result.food, isNull);
      expect(result.message, contains('No Open Food Facts product matched'));
    });

    test(
      'Open Food Facts adapter reports malformed product response',
      () async {
        final provider = OpenFoodFactsNutritionProvider(
          transport: _FakeOpenFoodFactsTransport(
            response: const OpenFoodFactsTransportResponse(
              statusCode: 200,
              body: '''
{
  "status": 1,
  "product": {
    "product_name": "Nameless macros",
    "nutriments": {
      "energy-kcal_serving": 80
    }
  }
}
''',
            ),
          ),
        );

        final result = await provider.lookup(
          const NutritionLookupQuery(
            foodName: 'skyr',
            barcode: '1234567890123',
          ),
        );

        expect(result.status, NutritionLookupStatus.malformedResponse);
        expect(result.food, isNull);
        expect(result.message, contains('malformed nutrition data'));
      },
    );

    test('Open Food Facts adapter reports transport errors', () async {
      final provider = OpenFoodFactsNutritionProvider(
        transport: _FakeOpenFoodFactsTransport(throwsError: true),
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'skyr', barcode: '1234567890123'),
      );

      expect(result.status, NutritionLookupStatus.providerUnavailable);
      expect(result.isProviderUnavailable, isTrue);
      expect(result.message, contains('lookup failed'));
    });

    test('Open Food Facts adapter reports rate limits', () async {
      final provider = OpenFoodFactsNutritionProvider(
        transport: _FakeOpenFoodFactsTransport(
          response: const OpenFoodFactsTransportResponse(
            statusCode: 429,
            body: '{"error":"too many requests"}',
          ),
        ),
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'skyr', barcode: '1234567890123'),
      );

      expect(result.status, NutritionLookupStatus.rateLimited);
      expect(result.isProviderUnavailable, isTrue);
      expect(result.message, contains('rate limit'));
    });

    test(
      'FoodData Central adapter reports missing API key explicitly',
      () async {
        const provider = FoodDataCentralNutritionProvider(apiKey: null);

        final result = await provider.lookup(
          const NutritionLookupQuery(foodName: 'salmon'),
        );

        expect(result.status, NutritionLookupStatus.missingApiKey);
        expect(result.isProviderUnavailable, isTrue);
        expect(result.message, contains('FoodData Central API key'));
        expect(result.message, contains('No app-owned key'));
      },
    );

    test('FoodData Central adapter parses search fixtures', () async {
      final client = _FakeFoodDataCentralSearchClient(
        response: FoodDataCentralSearchResponse.fromJson({
          'foods': [
            {
              'fdcId': 175167,
              'description': 'Salmon, raw',
              'servingSize': 100,
              'servingSizeUnit': 'g',
              'foodNutrients': [
                {'nutrientId': 1008, 'nutrientName': 'Energy', 'value': 208},
                {'nutrientId': 1003, 'nutrientName': 'Protein', 'value': 20.4},
                {
                  'nutrientId': 1005,
                  'nutrientName': 'Carbohydrate, by difference',
                  'value': 0,
                },
                {
                  'nutrientId': 1004,
                  'nutrientName': 'Total lipid (fat)',
                  'value': 13.4,
                },
              ],
            },
          ],
        }),
      );
      final provider = FoodDataCentralNutritionProvider(
        apiKey: 'user-owned-test-key',
        client: client,
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'salmon'),
      );

      expect(client.lastApiKey, 'user-owned-test-key');
      expect(client.lastQuery, 'salmon');
      expect(result.status, NutritionLookupStatus.verified);
      expect(result.providerName, 'fooddata-central');
      expect(result.food?.id, 'fdc-175167');
      expect(result.food?.name, 'Salmon, raw');
      expect(result.food?.servingDescription, '100 g serving');
      expect(result.food?.source.provider, 'fooddata-central');
      expect(result.food?.nutritionPerServing?.calories, 208);
      expect(result.food?.nutritionPerServing?.proteinGrams, 20.4);
      expect(result.food?.nutritionPerServing?.carbsGrams, 0);
      expect(result.food?.nutritionPerServing?.fatGrams, 13.4);
    });

    test('FoodData Central adapter reports no search results', () async {
      final provider = FoodDataCentralNutritionProvider(
        apiKey: 'user-owned-test-key',
        client: _FakeFoodDataCentralSearchClient(
          response: const FoodDataCentralSearchResponse(foods: []),
        ),
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'unknown food'),
      );

      expect(result.status, NutritionLookupStatus.notFound);
      expect(result.providerName, 'fooddata-central');
      expect(result.message, contains('No FoodData Central result'));
    });

    test('FoodData Central adapter reports provider errors', () async {
      final provider = FoodDataCentralNutritionProvider(
        apiKey: 'user-owned-test-key',
        client: _FakeFoodDataCentralSearchClient(
          failure: StateError('simulated transport failure'),
        ),
      );

      final result = await provider.lookup(
        const NutritionLookupQuery(foodName: 'salmon'),
      );

      expect(result.status, NutritionLookupStatus.providerUnavailable);
      expect(result.providerName, 'fooddata-central');
      expect(result.message, contains('FoodData Central lookup failed'));
      expect(result.message, isNot(contains('user-owned-test-key')));
    });

    test(
      'FoodData Central adapter distinguishes timeout and rate limit',
      () async {
        final timeoutProvider = FoodDataCentralNutritionProvider(
          apiKey: 'user-owned-test-key',
          client: _FakeFoodDataCentralSearchClient(
            failure: TimeoutException('simulated timeout'),
          ),
        );
        final rateLimitProvider = FoodDataCentralNutritionProvider(
          apiKey: 'user-owned-test-key',
          client: _FakeFoodDataCentralSearchClient(
            failure: const FoodDataCentralRateLimitException(),
          ),
        );

        final timeout = await timeoutProvider.lookup(
          const NutritionLookupQuery(foodName: 'salmon'),
        );
        final rateLimit = await rateLimitProvider.lookup(
          const NutritionLookupQuery(foodName: 'salmon'),
        );

        expect(timeout.status, NutritionLookupStatus.timeout);
        expect(timeout.message, contains('timed out'));
        expect(rateLimit.status, NutritionLookupStatus.rateLimited);
        expect(rateLimit.message, contains('rate limit'));
      },
    );
  });

  group('NutritionEnrichmentService', () {
    test('uses configured provider order before local fallback', () async {
      final first = _ScriptedNutritionLookupProvider(
        providerName: 'open-food-facts',
        result: const NutritionLookupResult(
          query: NutritionLookupQuery(foodName: 'salmon'),
          status: NutritionLookupStatus.notFound,
          providerName: 'open-food-facts',
          message: 'No barcode result.',
        ),
      );
      final second = _ScriptedNutritionLookupProvider(
        providerName: 'fooddata-central',
        result: const NutritionLookupResult(
          query: NutritionLookupQuery(foodName: 'salmon'),
          status: NutritionLookupStatus.verified,
          providerName: 'fooddata-central',
          food: _foodDataCentralSalmon,
          message: 'Matched configured FoodData Central nutrition.',
        ),
      );
      final service = NutritionEnrichmentService(
        providers: [first, second],
        fallbackProvider: LocalNutritionLookupProvider(foods: const []),
      );

      final result = await service.lookupFood(
        const NutritionLookupQuery(foodName: 'salmon'),
      );

      expect(result.status, NutritionLookupStatus.verified);
      expect(result.providerName, 'fooddata-central');
      expect(first.lookupCount, 1);
      expect(second.lookupCount, 1);
    });

    test('uses local fallback when a provider times out', () async {
      final service = NutritionEnrichmentService(
        providers: [
          _ScriptedNutritionLookupProvider(
            providerName: 'fooddata-central',
            delay: const Duration(milliseconds: 50),
            result: const NutritionLookupResult(
              query: NutritionLookupQuery(foodName: 'banana'),
              status: NutritionLookupStatus.verified,
              providerName: 'fooddata-central',
              food: _foodDataCentralSalmon,
            ),
          ),
        ],
        fallbackProvider: LocalNutritionLookupProvider(
          foods: NutritionSeedData.foods,
        ),
        policy: const NutritionLookupPolicy(
          providerTimeout: Duration(milliseconds: 1),
        ),
      );

      final result = await service.lookupFood(
        const NutritionLookupQuery(foodName: 'banana'),
      );

      expect(result.status, NutritionLookupStatus.fallback);
      expect(result.providerName, 'local-fallback');
      expect(result.message, contains('fooddata-central lookup timed out'));
      expect(result.food?.source.source, NutritionSource.fallback);
    });

    test(
      'returns a specific provider failure when no fallback is available',
      () async {
        final service = NutritionEnrichmentService(
          providers: [
            _ScriptedNutritionLookupProvider(
              providerName: 'fooddata-central',
              delay: const Duration(milliseconds: 50),
              result: const NutritionLookupResult(
                query: NutritionLookupQuery(foodName: 'unknown'),
                status: NutritionLookupStatus.verified,
                providerName: 'fooddata-central',
                food: _foodDataCentralSalmon,
              ),
            ),
          ],
          fallbackProvider: LocalNutritionLookupProvider(foods: const []),
          policy: const NutritionLookupPolicy(
            providerTimeout: Duration(milliseconds: 1),
          ),
        );

        final result = await service.lookupFood(
          const NutritionLookupQuery(foodName: 'unknown'),
        );

        expect(result.status, NutritionLookupStatus.timeout);
        expect(result.message, contains('timed out'));
      },
    );

    test('uses cached provider nutrition with preserved provenance', () async {
      final observedAt = DateTime.utc(2026, 6, 30, 9);
      final cache = NutritionLookupCache()
        ..write(
          NutritionLookupResult(
            query: const NutritionLookupQuery(foodName: 'salmon'),
            status: NutritionLookupStatus.verified,
            providerName: 'fooddata-central',
            food: _foodDataCentralSalmonWithObservedAt(observedAt),
            message: 'Matched cached FoodData Central nutrition.',
          ),
        );
      final service = NutritionEnrichmentService(
        providers: [
          _ScriptedNutritionLookupProvider(
            providerName: 'open-food-facts',
            result: const NutritionLookupResult(
              query: NutritionLookupQuery(foodName: 'salmon'),
              status: NutritionLookupStatus.notFound,
              providerName: 'open-food-facts',
            ),
          ),
        ],
        fallbackProvider: LocalNutritionLookupProvider(foods: const []),
        cache: cache,
      );

      final result = await service.lookupFood(
        const NutritionLookupQuery(foodName: 'salmon'),
      );

      expect(result.status, NutritionLookupStatus.verified);
      expect(result.providerName, 'fooddata-central');
      expect(result.food?.source.provider, 'fooddata-central');
      expect(result.food?.source.observedAt, observedAt);
      expect(
        result.message,
        contains('Used cached fooddata-central nutrition'),
      );
      expect(result.message, contains('open-food-facts'));
    });

    test('cache miss falls through to local not-found result', () async {
      final service = NutritionEnrichmentService(
        providers: [
          _ScriptedNutritionLookupProvider(
            providerName: 'fooddata-central',
            result: const NutritionLookupResult(
              query: NutritionLookupQuery(foodName: 'dragonfruit toast'),
              status: NutritionLookupStatus.notFound,
              providerName: 'fooddata-central',
            ),
          ),
        ],
        fallbackProvider: LocalNutritionLookupProvider(foods: const []),
        cache: NutritionLookupCache(),
      );

      final result = await service.lookupFood(
        const NutritionLookupQuery(foodName: 'dragonfruit toast'),
      );

      expect(result.status, NutritionLookupStatus.notFound);
      expect(result.providerName, 'local-fallback');
      expect(result.message, contains('No local nutrition record'));
    });

    test('fresh provider result supersedes disagreeing cached data', () async {
      final cache = NutritionLookupCache()
        ..write(
          NutritionLookupResult(
            query: const NutritionLookupQuery(foodName: 'salmon'),
            status: NutritionLookupStatus.verified,
            providerName: 'fooddata-central',
            food: _foodDataCentralSalmonWithObservedAt(
              DateTime.utc(2026, 6, 29, 8),
            ),
          ),
        );
      final service = NutritionEnrichmentService(
        providers: [
          _ScriptedNutritionLookupProvider(
            providerName: 'open-food-facts',
            result: const NutritionLookupResult(
              query: NutritionLookupQuery(foodName: 'salmon'),
              status: NutritionLookupStatus.verified,
              providerName: 'open-food-facts',
              food: _openFoodFactsSalmon,
              message: 'Matched packaged product nutrition by barcode.',
            ),
          ),
        ],
        fallbackProvider: LocalNutritionLookupProvider(foods: const []),
        cache: cache,
        now: () => DateTime.utc(2026, 6, 30, 9, 30),
      );

      final result = await service.lookupFood(
        const NutritionLookupQuery(foodName: 'salmon'),
      );

      expect(result.providerName, 'open-food-facts');
      expect(result.food?.id, 'off-salmon');
      expect(result.food?.source.provider, 'open-food-facts');
      expect(result.food?.source.observedAt, DateTime.utc(2026, 6, 30, 9, 30));
      expect(result.message, contains('Fresh open-food-facts data was used'));
      expect(result.message, contains('cached fooddata-central data'));
    });

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
          contains('FoodData Central API key'),
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

class _FakeOpenFoodFactsTransport implements OpenFoodFactsTransport {
  _FakeOpenFoodFactsTransport({this.response, this.throwsError = false});

  final OpenFoodFactsTransportResponse? response;
  final bool throwsError;

  Uri? lastUri;
  Map<String, String> lastHeaders = const {};

  @override
  Future<OpenFoodFactsTransportResponse> get(
    Uri uri,
    Map<String, String> headers,
  ) async {
    lastUri = uri;
    lastHeaders = Map.unmodifiable(headers);

    if (throwsError) {
      throw const FormatException('network unavailable');
    }

    return response ??
        const OpenFoodFactsTransportResponse(statusCode: 404, body: '{}');
  }
}

class _FakeFoodDataCentralSearchClient implements FoodDataCentralSearchClient {
  _FakeFoodDataCentralSearchClient({this.response, this.failure});

  final FoodDataCentralSearchResponse? response;
  final Object? failure;

  String? lastQuery;
  String? lastApiKey;

  @override
  Future<FoodDataCentralSearchResponse> searchFoods({
    required String query,
    required String apiKey,
  }) async {
    lastQuery = query;
    lastApiKey = apiKey;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return response ?? const FoodDataCentralSearchResponse(foods: []);
  }
}

class _ScriptedNutritionLookupProvider implements NutritionLookupProvider {
  _ScriptedNutritionLookupProvider({
    required this.providerName,
    required this.result,
    this.delay,
  });

  @override
  final String providerName;
  final NutritionLookupResult result;
  final Duration? delay;

  int lookupCount = 0;

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    lookupCount += 1;
    final delay = this.delay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return NutritionLookupResult(
      query: query,
      status: result.status,
      providerName: result.providerName,
      food: result.food,
      message: result.message,
    );
  }
}

const _foodDataCentralSalmon = FoodItem(
  id: 'fdc-salmon',
  name: 'Salmon, raw',
  servingDescription: '100 g serving',
  nutritionPerServing: MacroTotals(
    calories: 208,
    proteinGrams: 20.4,
    carbsGrams: 0,
    fatGrams: 13.4,
  ),
  source: SourceMetadata(
    source: NutritionSource.databaseVerified,
    label: 'FoodData Central',
    provider: 'fooddata-central',
  ),
);

const _openFoodFactsSalmon = FoodItem(
  id: 'off-salmon',
  name: 'Packaged salmon',
  servingDescription: '100 g serving',
  nutritionPerServing: MacroTotals(
    calories: 190,
    proteinGrams: 19,
    carbsGrams: 1,
    fatGrams: 11,
  ),
  source: SourceMetadata(
    source: NutritionSource.databaseVerified,
    label: 'Open Food Facts',
    provider: 'open-food-facts',
  ),
);

FoodItem _foodDataCentralSalmonWithObservedAt(DateTime observedAt) {
  return FoodItem(
    id: _foodDataCentralSalmon.id,
    name: _foodDataCentralSalmon.name,
    servingDescription: _foodDataCentralSalmon.servingDescription,
    nutritionPerServing: _foodDataCentralSalmon.nutritionPerServing,
    source: _foodDataCentralSalmon.source.copyWith(observedAt: observedAt),
  );
}
