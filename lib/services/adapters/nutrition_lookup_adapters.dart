import 'dart:convert';
import 'dart:io';

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

    final response = await _requestProduct(barcode);
    if (response == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
        providerName: providerName,
        message:
            'Open Food Facts returned HTTP ${response.statusCode} for barcode $barcode.',
      );
    }

    final parsed = _parseProductResponse(response.body, barcode);
    if (parsed == null) {
      return NutritionLookupResult(
        query: query,
        status: NutritionLookupStatus.providerError,
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
