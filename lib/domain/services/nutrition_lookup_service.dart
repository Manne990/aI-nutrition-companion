import '../models/nutrition.dart';

abstract interface class NutritionLookupProvider {
  String get providerName;

  Future<NutritionLookupResult> lookup(NutritionLookupQuery query);
}

class NutritionEnrichmentService {
  const NutritionEnrichmentService({
    required this.providers,
    required this.fallbackProvider,
  });

  final List<NutritionLookupProvider> providers;
  final NutritionLookupProvider fallbackProvider;

  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query) async {
    final providerResults = <NutritionLookupResult>[];

    for (final provider in providers) {
      final result = await provider.lookup(query);
      providerResults.add(result);
      if (result.isVerified || result.isFallback) {
        return result;
      }
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
    final unavailable = providerResults
        .where((result) => result.isProviderUnavailable)
        .map((result) => '${result.providerName}: ${result.message}')
        .join('; ');
    if (unavailable.isEmpty) {
      return fallback;
    }
    return NutritionLookupResult(
      query: fallback.query,
      status: fallback.status,
      providerName: fallback.providerName,
      food: fallback.food,
      message:
          '${fallback.message ?? 'Used fallback nutrition.'} '
          'Provider fallback reason: $unavailable',
    );
  }
}
