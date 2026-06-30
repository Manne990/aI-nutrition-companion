import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../domain/models/nutrition.dart';
import '../../domain/services/nutrition_lookup_service.dart';

abstract interface class FoodDataCentralSearchClient {
  Future<FoodDataCentralSearchResponse> searchFoods({
    required String query,
    required String apiKey,
  });
}

class FoodDataCentralSearchResponse {
  const FoodDataCentralSearchResponse({required this.foods});

  factory FoodDataCentralSearchResponse.fromJson(Map<String, Object?> json) {
    final rawFoods = json['foods'];
    if (rawFoods is! List) {
      return const FoodDataCentralSearchResponse(foods: []);
    }

    return FoodDataCentralSearchResponse(
      foods: List.unmodifiable(
        rawFoods
            .map(_asObjectMap)
            .nonNulls
            .map(FoodDataCentralSearchFood.fromJson)
            .nonNulls,
      ),
    );
  }

  final List<FoodDataCentralSearchFood> foods;

  FoodItem? firstUsableFood() {
    for (final food in foods) {
      final item = food.toFoodItem();
      if (item != null) {
        return item;
      }
    }
    return null;
  }
}

class FoodDataCentralSearchFood {
  const FoodDataCentralSearchFood({
    required this.description,
    required this.nutrients,
    this.fdcId,
    this.servingDescription,
  });

  static FoodDataCentralSearchFood? fromJson(Map<String, Object?> json) {
    final description = _asString(json['description'])?.trim();
    if (description == null || description.isEmpty) {
      return null;
    }

    return FoodDataCentralSearchFood(
      fdcId: _asString(json['fdcId']) ?? _asString(json['foodCode']),
      description: description,
      servingDescription: _servingDescription(json),
      nutrients: FoodDataCentralNutrients.fromJson(json['foodNutrients']),
    );
  }

  final String? fdcId;
  final String description;
  final String? servingDescription;
  final FoodDataCentralNutrients nutrients;

  FoodItem? toFoodItem() {
    final calories = nutrients.calories;
    final protein = nutrients.proteinGrams;
    final carbs = nutrients.carbsGrams;
    final fat = nutrients.fatGrams;
    if (calories == null || protein == null || carbs == null || fat == null) {
      return null;
    }

    final idSuffix =
        fdcId ?? normalizeFoodName(description).replaceAll(' ', '-');
    return FoodItem(
      id: 'fdc-$idSuffix',
      name: description,
      servingDescription: servingDescription ?? '100 g reference',
      nutritionPerServing: MacroTotals(
        calories: calories,
        proteinGrams: protein,
        carbsGrams: carbs,
        fatGrams: fat,
      ),
      source: const SourceMetadata(
        source: NutritionSource.databaseVerified,
        label: 'FoodData Central',
        provider: 'fooddata-central',
      ),
    );
  }
}

class FoodDataCentralNutrients {
  const FoodDataCentralNutrients({
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
  });

  factory FoodDataCentralNutrients.fromJson(Object? rawNutrients) {
    if (rawNutrients is! List) {
      return const FoodDataCentralNutrients();
    }

    double? calories;
    double? protein;
    double? carbs;
    double? fat;

    for (final rawNutrient in rawNutrients) {
      final nutrient = _asObjectMap(rawNutrient);
      if (nutrient == null) {
        continue;
      }

      final id = _asInt(nutrient['nutrientId']);
      final name = _asString(nutrient['nutrientName'])?.toLowerCase() ?? '';
      final value = _asDouble(nutrient['value'] ?? nutrient['nutrientNumber']);
      if (value == null) {
        continue;
      }

      if (id == 1008 || name.contains('energy')) {
        calories ??= value;
      } else if (id == 1003 || name.contains('protein')) {
        protein ??= value;
      } else if (id == 1005 || name.contains('carbohydrate')) {
        carbs ??= value;
      } else if (id == 1004 ||
          name.contains('total lipid') ||
          name.contains('total fat')) {
        fat ??= value;
      }
    }

    return FoodDataCentralNutrients(
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
    );
  }

  final double? calories;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
}

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
    this.simulateFailure = false,
    this.transport,
    this.baseProductUrl = 'https://world.openfoodfacts.org/api/v3/product',
    this.userAgent = defaultUserAgent,
  });

  static const defaultUserAgent =
      'AI Nutrition Companion/1.0 (+https://github.com/Manne990/aI-nutrition-companion)';

  final bool simulateFailure;
  final OpenFoodFactsTransport? transport;
  final String baseProductUrl;
  final String userAgent;

  @override
  String get providerName => 'open-food-facts';

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    if (simulateFailure) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerUnavailable,
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

    final response = await _requestProduct(barcode);
    if (response == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerUnavailable,
        providerName: providerName,
        message: 'Open Food Facts lookup failed in the adapter boundary.',
      );
    }

    if (response.statusCode == 404) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.notFound,
        providerName: providerName,
        message: 'No Open Food Facts product matched barcode $barcode.',
      );
    }

    if (response.statusCode == 429) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.rateLimited,
        providerName: providerName,
        message:
            'Open Food Facts rate limit was reached. Try again later or keep local fallback nutrition.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerUnavailable,
        providerName: providerName,
        message:
            'Open Food Facts returned HTTP ${response.statusCode} for barcode $barcode.',
      );
    }

    final parsed = _parseProductResponse(response.body, barcode);
    if (parsed == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.malformedResponse,
        providerName: providerName,
        message: 'Open Food Facts returned malformed nutrition data.',
      );
    }

    if (parsed == _OpenFoodFactsParsedProduct.notFound) {
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
      food: parsed.food,
      message: 'Matched packaged product nutrition by barcode.',
    );
  }

  Future<OpenFoodFactsTransportResponse?> _requestProduct(
    String barcode,
  ) async {
    final uri = Uri.parse(
      '$baseProductUrl/${Uri.encodeComponent(barcode)}.json',
    );
    try {
      return await (transport ?? const OpenFoodFactsHttpTransport()).get(uri, {
        HttpHeaders.userAgentHeader: userAgent,
        HttpHeaders.acceptHeader: 'application/json',
      });
    } on Object {
      return null;
    }
  }

  _OpenFoodFactsParsedProduct? _parseProductResponse(
    String body,
    String barcode,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on Object {
      return null;
    }

    if (decoded is! Map<String, Object?>) {
      return null;
    }

    if (decoded['status'] == 0) {
      return _OpenFoodFactsParsedProduct.notFound;
    }

    final product = decoded['product'];
    if (product is! Map<String, Object?>) {
      return null;
    }

    final name = _firstNonEmptyString(product, const [
      'product_name',
      'product_name_en',
      'generic_name',
    ]);
    final nutriments = product['nutriments'];
    if (name == null || nutriments is! Map<String, Object?>) {
      return null;
    }

    final calories = _firstNumber(nutriments, const [
      'energy-kcal_serving',
      'energy-kcal_100g',
      'energy-kcal',
    ]);
    final protein = _firstNumber(nutriments, const [
      'proteins_serving',
      'proteins_100g',
      'proteins',
    ]);
    final carbs = _firstNumber(nutriments, const [
      'carbohydrates_serving',
      'carbohydrates_100g',
      'carbohydrates',
    ]);
    final fat = _firstNumber(nutriments, const [
      'fat_serving',
      'fat_100g',
      'fat',
    ]);
    if (calories == null || protein == null || carbs == null || fat == null) {
      return null;
    }

    return _OpenFoodFactsParsedProduct(
      FoodItem(
        id: 'off-$barcode',
        name: name,
        servingDescription:
            _firstNonEmptyString(product, const ['serving_size', 'quantity']) ??
            'Open Food Facts serving',
        nutritionPerServing: MacroTotals(
          calories: calories,
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fat,
        ),
        source: const SourceMetadata(
          source: NutritionSource.databaseVerified,
          label: 'Open Food Facts',
          provider: 'open-food-facts',
          confidence: 0.95,
        ),
      ),
    );
  }
}

abstract interface class OpenFoodFactsTransport {
  Future<OpenFoodFactsTransportResponse> get(
    Uri uri,
    Map<String, String> headers,
  );
}

class OpenFoodFactsTransportResponse {
  const OpenFoodFactsTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class OpenFoodFactsHttpTransport implements OpenFoodFactsTransport {
  const OpenFoodFactsHttpTransport();

  @override
  Future<OpenFoodFactsTransportResponse> get(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      return OpenFoodFactsTransportResponse(
        statusCode: response.statusCode,
        body: body,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class _OpenFoodFactsParsedProduct {
  const _OpenFoodFactsParsedProduct(this.food);

  static const notFound = _OpenFoodFactsParsedProduct(null);

  final FoodItem? food;
}

String? _firstNonEmptyString(Map<String, Object?> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

double? _firstNumber(Map<String, Object?> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

class FoodDataCentralNutritionProvider implements NutritionLookupProvider {
  const FoodDataCentralNutritionProvider({
    required this.apiKey,
    this.client,
    this.foodsByName = const {},
    this.simulateFailure = false,
  });

  final String? apiKey;
  final FoodDataCentralSearchClient? client;
  final Map<String, FoodItem> foodsByName;
  final bool simulateFailure;

  @override
  String get providerName => 'fooddata-central';

  @override
  Future<NutritionLookupResult> lookup(NutritionLookupQuery query) async {
    final configuredApiKey = apiKey?.trim() ?? '';
    if (configuredApiKey.isEmpty) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.missingApiKey,
        providerName: providerName,
        message:
            'Add a FoodData Central API key to use generic food search. '
            'No app-owned key is bundled.',
      );
    }

    if (simulateFailure) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerUnavailable,
        providerName: providerName,
        message: 'FoodData Central lookup failed in the adapter boundary.',
      );
    }

    final searchClient = client;
    if (searchClient != null) {
      try {
        final response = await searchClient.searchFoods(
          query: query.foodName,
          apiKey: configuredApiKey,
        );
        if (response.foods.isEmpty) {
          return NutritionLookupResult(
            query: query,
            status: NutritionLookupStatus.notFound,
            providerName: providerName,
            message: 'No FoodData Central result matched "${query.foodName}".',
          );
        }

        final food = response.firstUsableFood();
        if (food == null) {
          return NutritionLookupResult(
            query: query,
            status: NutritionLookupStatus.malformedResponse,
            providerName: providerName,
            message:
                'FoodData Central response did not include calories, protein, '
                'carbs, and fat.',
          );
        }

        return NutritionLookupResult(
          query: query,
          status: NutritionLookupStatus.verified,
          providerName: providerName,
          food: food,
          message: 'Matched FoodData Central search nutrition.',
        );
      } on TimeoutException {
        return NutritionLookupResult(
          query: query,
          status: NutritionLookupStatus.timeout,
          providerName: providerName,
          message: 'FoodData Central lookup timed out.',
        );
      } on FoodDataCentralRateLimitException {
        return NutritionLookupResult(
          query: query,
          status: NutritionLookupStatus.rateLimited,
          providerName: providerName,
          message:
              'FoodData Central rate limit was reached. Try again later or use local fallback nutrition.',
        );
      } catch (_) {
        return NutritionLookupResult(
          query: query,
          status: NutritionLookupStatus.providerUnavailable,
          providerName: providerName,
          message: 'FoodData Central lookup failed in the adapter boundary.',
        );
      }
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

class FoodDataCentralRateLimitException implements Exception {
  const FoodDataCentralRateLimitException();
}

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _servingDescription(Map<String, Object?> json) {
  final servingSize = _asDouble(json['servingSize']);
  final servingUnit = _asString(json['servingSizeUnit']);
  if (servingSize == null || servingUnit == null || servingUnit.isEmpty) {
    return null;
  }
  final formattedSize = servingSize == servingSize.roundToDouble()
      ? servingSize.toStringAsFixed(0)
      : servingSize.toString();
  return '$formattedSize $servingUnit serving';
}
