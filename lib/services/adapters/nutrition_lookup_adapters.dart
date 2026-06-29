import '../../domain/models/nutrition.dart';
import '../../domain/services/nutrition_lookup_service.dart';

class LocalNutritionLookupProvider implements NutritionLookupProvider {
  LocalNutritionLookupProvider({required Iterable<FoodItem> foods})
    : _foods = List.unmodifiable(foods);

  final List<FoodItem> _foods;

  @override
  String get providerName => 'local-fallback';

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    final match = _matchFood(query.normalizedFoodName);
    if (match == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.notFound,
        providerName: providerName,
        message: 'No local nutrition record matched "${query.foodName}".',
      );
    }

    final status = match.source.source == NutritionSource.databaseVerified
        ? NutritionLookupStatus.verified
        : NutritionLookupStatus.fallback;
    return NutritionLookupResult(
      query: query,
      status: status,
      providerName: providerName,
      food: match,
      message: status == NutritionLookupStatus.verified
          ? 'Matched a verified local nutrition record.'
          : 'Matched local fallback nutrition; confirm if precision matters.',
    );
  }

  FoodItem? _matchFood(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return null;
    }

    for (final food in _foods) {
      if (normalizeFoodName(food.name) == normalizedQuery) {
        return food;
      }
    }

    for (final food in _foods) {
      final normalizedFood = normalizeFoodName(food.name);
      if (normalizedFood.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedFood)) {
        return food;
      }
    }

    return null;
  }
}

class OpenFoodFactsNutritionProvider implements NutritionLookupProvider {
  const OpenFoodFactsNutritionProvider({
    this.packagedProducts = const {},
    this.simulateFailure = false,
  });

  final Map<String, FoodItem> packagedProducts;
  final bool simulateFailure;

  @override
  String get providerName => 'open-food-facts';

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    if (simulateFailure) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
        providerName: providerName,
        message: 'Open Food Facts lookup failed in the adapter boundary.',
      );
    }

    final barcode = query.barcode?.trim();
    if (barcode == null || barcode.isEmpty) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.notFound,
        providerName: providerName,
        message: 'Open Food Facts requires a barcode for packaged lookup.',
      );
    }

    final product = packagedProducts[barcode];
    if (product == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.notFound,
        providerName: providerName,
        message: 'No Open Food Facts product matched barcode $barcode.',
      );
    }

    return NutritionLookupResult(
      query: query,
      status: NutritionLookupStatus.verified,
      providerName: providerName,
      food: product,
      message: 'Matched packaged product nutrition by barcode.',
    );
  }
}

class FoodDataCentralNutritionProvider implements NutritionLookupProvider {
  const FoodDataCentralNutritionProvider({
    required this.apiKey,
    this.foodsByName = const {},
    this.simulateFailure = false,
  });

  final String? apiKey;
  final Map<String, FoodItem> foodsByName;
  final bool simulateFailure;

  @override
  String get providerName => 'fooddata-central';

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    if (apiKey == null || apiKey!.trim().isEmpty) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.missingApiKey,
        providerName: providerName,
        message: 'FOODDATA_CENTRAL_API_KEY is not configured.',
      );
    }

    if (simulateFailure) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
        providerName: providerName,
        message: 'FoodData Central lookup failed in the adapter boundary.',
      );
    }

    final food = foodsByName[query.normalizedFoodName];
    if (food == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.notFound,
        providerName: providerName,
        message: 'No FoodData Central fixture matched "${query.foodName}".',
      );
    }

    return NutritionLookupResult(
      query: query,
      status: NutritionLookupStatus.verified,
      providerName: providerName,
      food: food,
      message: 'Matched configured FoodData Central nutrition.',
    );
  }
}
