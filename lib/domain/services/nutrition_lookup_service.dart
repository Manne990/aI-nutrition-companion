import 'dart:async';

import '../models/nutrition.dart';

abstract interface class NutritionLookupProvider {
  String get providerName;

  Future<NutritionLookupResult> lookup(NutritionLookupQuery query);
}

class NutritionLookupPolicy {
  const NutritionLookupPolicy({this.providerTimeout});

  final Duration? providerTimeout;
}

class NutritionLookupCache {
  final Map<String, NutritionLookupResult> _resultsByKey = {};

  NutritionLookupResult? read(NutritionLookupQuery query) {
    return _resultsByKey[_cacheKey(query)];
  }

  void write(NutritionLookupResult result) {
    if (!result.isVerified) {
      return;
    }
    final source = result.food?.source;
    if (source?.provider == null || source?.observedAt == null) {
      return;
    }
    _resultsByKey[_cacheKey(result.query)] = result;
  }

  static String _cacheKey(NutritionLookupQuery query) {
    final barcode = query.barcode?.trim() ?? '';
    final serving = query.servingDescription?.trim() ?? '';
    return [query.normalizedFoodName, barcode, serving].join('|');
  }
}

class NutritionEnrichmentService {
  NutritionEnrichmentService({
    required this.providers,
    required this.fallbackProvider,
    this.policy = const NutritionLookupPolicy(),
    this.cache,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final List<NutritionLookupProvider> providers;
  final NutritionLookupProvider fallbackProvider;
  final NutritionLookupPolicy policy;
  final NutritionLookupCache? cache;
  final DateTime Function() _now;

  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query) async {
    final providerResults = <NutritionLookupResult>[];

    for (final provider in providers) {
      final result = await _lookupProvider(provider, query);
      providerResults.add(result);
      if (result.isVerified || result.isFallback) {
        return _recordFreshResult(result, query);
      }
    }

    final cached = cache?.read(query);
    if (cached != null) {
      return _withProviderContext(_cacheHit(cached), providerResults);
    }

    final fallback = await fallbackProvider.lookup(query);
    if (fallback.hasFood) {
      return _withProviderContext(fallback, providerResults);
    }

    return providerResults.firstWhere(
      (result) => result.isProviderUnavailable,
      orElse: () => fallback,
    );
  }

  Future<NutritionLookupResult> _lookupProvider(
    NutritionLookupProvider provider,
    NutritionLookupQuery query,
  ) async {
    try {
      final timeout = policy.providerTimeout;
      final lookup = provider.lookup(query);
      if (timeout == null) {
        return await lookup;
      }
      return await lookup.timeout(timeout);
    } on TimeoutException {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
        providerName: provider.providerName,
        message: '${provider.providerName} lookup timed out.',
      );
    } on Object {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
        providerName: provider.providerName,
        message: '${provider.providerName} lookup failed.',
      );
    }
  }

  NutritionLookupResult _recordFreshResult(
    NutritionLookupResult result,
    NutritionLookupQuery query,
  ) {
    final cache = this.cache;
    if (cache == null || !result.isVerified) {
      return result;
    }

    final existing = cache.read(query);
    final cacheable = _cacheableResult(result);
    cache.write(cacheable);

    if (existing != null && _resultsDisagree(existing, cacheable)) {
      return _copyResult(
        cacheable,
        message:
            '${cacheable.message ?? 'Matched fresh provider nutrition.'} '
            'Fresh ${cacheable.food?.source.provider ?? cacheable.providerName} '
            'data was used instead of cached '
            '${existing.food?.source.provider ?? existing.providerName} data.',
      );
    }

    return cacheable;
  }

  NutritionLookupResult _cacheableResult(NutritionLookupResult result) {
    final food = result.food;
    if (food == null) {
      return result;
    }

    final source = food.source;
    final provider = source.provider ?? result.providerName;
    if (provider.isEmpty) {
      return result;
    }

    final observedAt = source.observedAt ?? _now();
    return _copyResult(
      result,
      food: _copyFood(
        food,
        source: source.copyWith(provider: provider, observedAt: observedAt),
      ),
    );
  }

  NutritionLookupResult _cacheHit(NutritionLookupResult cached) {
    final source = cached.food?.source;
    final provider = source?.provider ?? cached.providerName;
    final observedAt = source?.observedAt;
    final observedText = observedAt == null
        ? 'with preserved source metadata'
        : 'observed at ${observedAt.toIso8601String()}';
    return _copyResult(
      cached,
      message:
          'Used cached $provider nutrition $observedText. '
          'Fresh providers were unavailable or had no match.',
    );
  }

  bool _resultsDisagree(
    NutritionLookupResult cached,
    NutritionLookupResult fresh,
  ) {
    final cachedFood = cached.food;
    final freshFood = fresh.food;
    if (cachedFood == null || freshFood == null) {
      return false;
    }
    if (cachedFood.id != freshFood.id ||
        cachedFood.source.provider != freshFood.source.provider) {
      return true;
    }
    return _macroTotalsDisagree(
      cachedFood.nutritionPerServing,
      freshFood.nutritionPerServing,
    );
  }

  bool _macroTotalsDisagree(MacroTotals? cached, MacroTotals? fresh) {
    if (cached == null || fresh == null) {
      return cached != fresh;
    }
    return cached.calories != fresh.calories ||
        cached.proteinGrams != fresh.proteinGrams ||
        cached.carbsGrams != fresh.carbsGrams ||
        cached.fatGrams != fresh.fatGrams;
  }

  Future<MealEnrichment> enrichMealItems(List<MealItem> items) async {
    final enrichedItems = <MealItem>[];
    final lookupResults = <NutritionLookupResult>[];

    for (final item in items) {
      if (item.food.source.isVerified && item.hasKnownNutrition) {
        enrichedItems.add(item);
        continue;
      }

      final query = NutritionLookupQuery(
        foodName: item.food.name,
        servingDescription: item.food.servingDescription,
      );
      final result = await lookupFood(query);
      lookupResults.add(result);

      final food = result.food;
      if (food == null) {
        enrichedItems.add(item);
        continue;
      }

      enrichedItems.add(
        item.copyWith(
          food: food,
          source: item.source.copyWith(
            label: '${item.source.label ?? 'AI estimate'} with lookup facts',
          ),
        ),
      );
    }

    return MealEnrichment(
      items: List.unmodifiable(enrichedItems),
      lookupResults: List.unmodifiable(lookupResults),
    );
  }

  Future<MealEstimate> enrichMealEstimate(MealEstimate estimate) async {
    final enrichment = await enrichMealItems(estimate.items);
    return MealEstimate(
      id: estimate.id,
      estimatedAt: estimate.estimatedAt,
      items: enrichment.items,
      source: estimate.source,
      photoPath: estimate.photoPath,
    );
  }

  NutritionLookupResult _withProviderContext(
    NutritionLookupResult fallback,
    List<NutritionLookupResult> providerResults,
  ) {
    final sourceGaps = providerResults
        .where((result) => !result.isVerified && !result.isFallback)
        .map(
          (result) =>
              '${result.providerName}: ${result.message ?? result.status.name}',
        )
        .join('; ');
    if (sourceGaps.isEmpty) {
      return fallback;
    }
    return _copyResult(
      fallback,
      message:
          '${fallback.message ?? 'Used fallback nutrition.'} '
          'Provider fallback reason: $sourceGaps',
    );
  }

  NutritionLookupResult _copyResult(
    NutritionLookupResult result, {
    FoodItem? food,
    String? message,
  }) {
    return NutritionLookupResult(
      query: result.query,
      status: result.status,
      providerName: result.providerName,
      food: food ?? result.food,
      message: message ?? result.message,
    );
  }

  FoodItem _copyFood(FoodItem food, {required SourceMetadata source}) {
    return FoodItem(
      id: food.id,
      name: food.name,
      servingDescription: food.servingDescription,
      source: source,
      nutritionPerServing: food.nutritionPerServing,
      allergens: food.allergens,
    );
  }
}
