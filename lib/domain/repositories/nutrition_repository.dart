import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/adapters/nutrition_lookup_adapters.dart';
import '../models/nutrition.dart';
import '../services/nutrition_lookup_service.dart';

abstract interface class NutritionRepository {
  List<FoodItem> foods();

  List<Meal> meals();

  List<WeightEntry> weightEntries();

  List<KitchenInventoryItem> kitchenInventory();

  List<KitchenFavoriteMeal> favoriteMeals();

  NutritionGoal nutritionGoal();

  UserPreferences userPreferences();

  DailySummary dailySummary(DateTime date);

  List<QuickLogSuggestion> quickLogSuggestions(DateTime now);

  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query);

  Future<MealEnrichment> enrichMealItems(List<MealItem> items);

  Future<MealEstimate> enrichMealEstimate(MealEstimate estimate);

  Meal saveMeal(Meal meal);

  Meal confirmQuickLogSuggestion(
    QuickLogSuggestion suggestion, {
    required DateTime eatenAt,
  });

  WeightEntry saveWeightEntry(WeightEntry entry);
}

class InMemoryNutritionRepository implements NutritionRepository {
  InMemoryNutritionRepository({
    List<FoodItem>? seedFoods,
    List<Meal>? seedMeals,
    List<WeightEntry>? seedWeightEntries,
    NutritionGoal? seedGoal,
    UserPreferences? seedPreferences,
    NutritionEnrichmentService? lookupService,
  }) : _foods = List.of(seedFoods ?? NutritionSeedData.foods),
       _meals = List.of(seedMeals ?? NutritionSeedData.meals),
       _weightEntries = List.of(
         seedWeightEntries ?? NutritionSeedData.weightEntries,
       ),
       _goal = seedGoal ?? NutritionSeedData.goal,
       _preferences = seedPreferences ?? NutritionSeedData.preferences,
       _lookupService =
           lookupService ??
           NutritionEnrichmentService(
             providers: const [
               OpenFoodFactsNutritionProvider(),
               FoodDataCentralNutritionProvider(apiKey: null),
             ],
             fallbackProvider: LocalNutritionLookupProvider(
               foods: seedFoods ?? NutritionSeedData.foods,
             ),
           );

  final List<FoodItem> _foods;
  final List<Meal> _meals;
  final List<WeightEntry> _weightEntries;
  final NutritionGoal _goal;
  final UserPreferences _preferences;
  final NutritionEnrichmentService _lookupService;

  @override
  List<FoodItem> foods() => List.unmodifiable(_foods);

  @override
  List<Meal> meals() => List.unmodifiable(_meals);

  @override
  List<WeightEntry> weightEntries() => List.unmodifiable(_weightEntries);

  @override
  List<KitchenInventoryItem> kitchenInventory() {
    return buildKitchenInventory(foods: _foods, meals: _meals);
  }

  @override
  List<KitchenFavoriteMeal> favoriteMeals() {
    return buildFavoriteMeals(_meals);
  }

  @override
  NutritionGoal nutritionGoal() => _goal;

  @override
  UserPreferences userPreferences() => _preferences;

  @override
  DailySummary dailySummary(DateTime date) {
    return buildDailySummary(
      date: date,
      meals: _meals,
      goal: _goal,
      weights: _weightEntries,
    );
  }

  @override
  List<QuickLogSuggestion> quickLogSuggestions(DateTime now) {
    return buildQuickLogSuggestions(now: now, foods: _foods, meals: _meals);
  }

  @override
  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query) {
    return _lookupService.lookupFood(query);
  }

  @override
  Future<MealEnrichment> enrichMealItems(List<MealItem> items) {
    return _lookupService.enrichMealItems(items);
  }

  @override
  Future<MealEstimate> enrichMealEstimate(MealEstimate estimate) {
    return _lookupService.enrichMealEstimate(estimate);
  }

  @override
  Meal saveMeal(Meal meal) {
    _meals.removeWhere((existing) => existing.id == meal.id);
    _meals.add(meal);
    _meals.sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    return meal;
  }

  @override
  Meal confirmQuickLogSuggestion(
    QuickLogSuggestion suggestion, {
    required DateTime eatenAt,
  }) {
    return saveMeal(suggestion.toMeal(eatenAt: eatenAt));
  }

  @override
  WeightEntry saveWeightEntry(WeightEntry entry) {
    _weightEntries.removeWhere((existing) => existing.id == entry.id);
    _weightEntries.add(entry);
    _weightEntries.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return entry;
  }
}

class SharedPreferencesNutritionRepository extends InMemoryNutritionRepository {
  factory SharedPreferencesNutritionRepository(
    SharedPreferences preferences, {
    List<FoodItem>? seedFoods,
    List<Meal>? seedMeals,
    List<WeightEntry>? seedWeightEntries,
    NutritionGoal? seedGoal,
    UserPreferences? seedPreferences,
    NutritionEnrichmentService? lookupService,
  }) {
    final persistedState = _NutritionPersistenceState.fromRaw(
      preferences.getString(stateKey),
    );
    return SharedPreferencesNutritionRepository._(
      preferences,
      seedFoods: seedFoods,
      seedMeals: persistedState?.meals ?? seedMeals,
      seedWeightEntries: persistedState?.weightEntries ?? seedWeightEntries,
      seedGoal: seedGoal,
      seedPreferences: seedPreferences,
      lookupService: lookupService,
    );
  }

  SharedPreferencesNutritionRepository._(
    this._sharedPreferences, {
    super.seedFoods,
    super.seedMeals,
    super.seedWeightEntries,
    super.seedGoal,
    super.seedPreferences,
    super.lookupService,
  });

  static const stateKey = 'nutrition.state.v1';

  final SharedPreferences _sharedPreferences;
  Future<void>? _pendingPersist;

  static Future<SharedPreferencesNutritionRepository> create({
    List<FoodItem>? seedFoods,
    List<Meal>? seedMeals,
    List<WeightEntry>? seedWeightEntries,
    NutritionGoal? seedGoal,
    UserPreferences? seedPreferences,
    NutritionEnrichmentService? lookupService,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesNutritionRepository(
      preferences,
      seedFoods: seedFoods,
      seedMeals: seedMeals,
      seedWeightEntries: seedWeightEntries,
      seedGoal: seedGoal,
      seedPreferences: seedPreferences,
      lookupService: lookupService,
    );
  }

  @override
  Meal saveMeal(Meal meal) {
    final saved = super.saveMeal(meal);
    _schedulePersist();
    return saved;
  }

  @override
  WeightEntry saveWeightEntry(WeightEntry entry) {
    final saved = super.saveWeightEntry(entry);
    _schedulePersist();
    return saved;
  }

  Future<void> flushPendingWrites() async {
    await _pendingPersist;
  }

  void _schedulePersist() {
    _pendingPersist = (_pendingPersist ?? Future<void>.value()).then(
      (_) => _persistState(),
    );
    unawaited(_pendingPersist);
  }

  Future<void> _persistState() async {
    await _sharedPreferences.setString(
      stateKey,
      jsonEncode({
        'version': 1,
        'meals': meals().map(_mealToJson).toList(growable: false),
        'weightEntries': weightEntries()
            .map(_weightEntryToJson)
            .toList(growable: false),
      }),
    );
  }
}

class _NutritionPersistenceState {
  const _NutritionPersistenceState({
    required this.meals,
    required this.weightEntries,
  });

  final List<Meal> meals;
  final List<WeightEntry> weightEntries;

  static _NutritionPersistenceState? fromRaw(String? rawState) {
    if (rawState == null || rawState.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawState);
      if (decoded is! Map) {
        return null;
      }

      final state = Map<String, Object?>.from(decoded);
      final rawMeals = state['meals'];
      final rawWeightEntries = state['weightEntries'];
      if (rawMeals is! List || rawWeightEntries is! List) {
        return null;
      }

      return _NutritionPersistenceState(
        meals: rawMeals
            .whereType<Map>()
            .map(_tryMealFromJson)
            .nonNulls
            .toList(growable: false),
        weightEntries: rawWeightEntries
            .whereType<Map>()
            .map(_tryWeightEntryFromJson)
            .nonNulls
            .toList(growable: false),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}

Map<String, Object?> _mealToJson(Meal meal) {
  return {
    'id': meal.id,
    'name': meal.name,
    'eatenAt': meal.eatenAt.toIso8601String(),
    'items': meal.items.map(_mealItemToJson).toList(growable: false),
    'source': _sourceToJson(meal.source),
    'photoPath': meal.photoPath,
  };
}

Meal? _tryMealFromJson(Map<Object?, Object?> rawJson) {
  try {
    final json = Map<String, Object?>.from(rawJson);
    final items = json['items'];
    if (items is! List) {
      return null;
    }

    final eatenAt = _dateTime(json['eatenAt']);
    if (eatenAt == null) {
      return null;
    }

    return Meal(
      id: _requiredString(json['id']),
      name: _requiredString(json['name']),
      eatenAt: eatenAt,
      items: items
          .whereType<Map>()
          .map(_tryMealItemFromJson)
          .nonNulls
          .toList(growable: false),
      source: _sourceFromJson(json['source']),
      photoPath: _nullableString(json['photoPath']),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Map<String, Object?> _mealItemToJson(MealItem item) {
  return {
    'id': item.id,
    'food': _foodItemToJson(item.food),
    'servings': item.servings,
    'source': _sourceToJson(item.source),
    'userNote': item.userNote,
    'replacesEstimateId': item.replacesEstimateId,
  };
}

MealItem? _tryMealItemFromJson(Map<Object?, Object?> rawJson) {
  try {
    final json = Map<String, Object?>.from(rawJson);
    final food = _tryFoodItemFromJson(_rawMap(json['food']));
    if (food == null) {
      return null;
    }

    return MealItem(
      id: _requiredString(json['id']),
      food: food,
      servings: _requiredDouble(json['servings']),
      source: _sourceFromJson(json['source']),
      userNote: _nullableString(json['userNote']),
      replacesEstimateId: _nullableString(json['replacesEstimateId']),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Map<String, Object?> _foodItemToJson(FoodItem food) {
  return {
    'id': food.id,
    'name': food.name,
    'servingDescription': food.servingDescription,
    'nutritionPerServing': food.nutritionPerServing == null
        ? null
        : _macroTotalsToJson(food.nutritionPerServing!),
    'source': _sourceToJson(food.source),
    'allergens': food.allergens,
  };
}

FoodItem? _tryFoodItemFromJson(Map<Object?, Object?>? rawJson) {
  if (rawJson == null) {
    return null;
  }

  try {
    final json = Map<String, Object?>.from(rawJson);
    final rawAllergens = json['allergens'];
    return FoodItem(
      id: _requiredString(json['id']),
      name: _requiredString(json['name']),
      servingDescription: _requiredString(json['servingDescription']),
      nutritionPerServing: _tryMacroTotalsFromJson(
        _rawMap(json['nutritionPerServing']),
      ),
      source: _sourceFromJson(json['source']),
      allergens: rawAllergens is List
          ? rawAllergens.whereType<String>().toList(growable: false)
          : const [],
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Map<String, Object?> _weightEntryToJson(WeightEntry entry) {
  return {
    'id': entry.id,
    'recordedAt': entry.recordedAt.toIso8601String(),
    'weightKg': entry.weightKg,
    'source': _sourceToJson(entry.source),
  };
}

WeightEntry? _tryWeightEntryFromJson(Map<Object?, Object?> rawJson) {
  try {
    final json = Map<String, Object?>.from(rawJson);
    final recordedAt = _dateTime(json['recordedAt']);
    if (recordedAt == null) {
      return null;
    }

    return WeightEntry(
      id: _requiredString(json['id']),
      recordedAt: recordedAt,
      weightKg: _requiredDouble(json['weightKg']),
      source: _sourceFromJson(json['source']),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Map<String, Object?> _sourceToJson(SourceMetadata source) {
  return {
    'source': source.source.name,
    'label': source.label,
    'provider': source.provider,
    'confidence': source.confidence,
    'observedAt': source.observedAt?.toIso8601String(),
  };
}

SourceMetadata _sourceFromJson(Object? rawSource) {
  final json = _rawMap(rawSource);
  if (json == null) {
    return NutritionSeedData.fallbackSource;
  }

  final sourceName = json['source'];
  return SourceMetadata(
    source: sourceName is String
        ? NutritionSource.values.byName(sourceName)
        : NutritionSource.fallback,
    label: _nullableString(json['label']),
    provider: _nullableString(json['provider']),
    confidence: _nullableDouble(json['confidence']),
    observedAt: _dateTime(json['observedAt']),
  );
}

Map<String, Object?> _macroTotalsToJson(MacroTotals totals) {
  return {
    'calories': totals.calories,
    'proteinGrams': totals.proteinGrams,
    'carbsGrams': totals.carbsGrams,
    'fatGrams': totals.fatGrams,
  };
}

MacroTotals? _tryMacroTotalsFromJson(Map<Object?, Object?>? rawJson) {
  if (rawJson == null) {
    return null;
  }

  try {
    final json = Map<String, Object?>.from(rawJson);
    return MacroTotals(
      calories: _requiredDouble(json['calories']),
      proteinGrams: _requiredDouble(json['proteinGrams']),
      carbsGrams: _requiredDouble(json['carbsGrams']),
      fatGrams: _requiredDouble(json['fatGrams']),
    );
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Map<Object?, Object?>? _rawMap(Object? value) {
  return value is Map ? value : null;
}

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw const FormatException('Required string field is missing.');
}

String? _nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

double _requiredDouble(Object? value) {
  final parsed = _nullableDouble(value);
  if (parsed == null) {
    throw const FormatException('Required numeric field is missing.');
  }
  return parsed;
}

double? _nullableDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

class NutritionSeedData {
  const NutritionSeedData._();

  static final _seedDay = DateTime(2026, 6, 29);

  static const databaseSource = SourceMetadata(
    source: NutritionSource.databaseVerified,
    label: 'Verified nutrition database',
    provider: 'local-seed',
    confidence: 1,
  );

  static const aiSource = SourceMetadata(
    source: NutritionSource.aiEstimated,
    label: 'AI estimate',
    provider: 'mock-ai',
    confidence: 0.72,
  );

  static const userSource = SourceMetadata(
    source: NutritionSource.userConfirmed,
    label: 'User confirmed',
  );

  static const fallbackSource = SourceMetadata(
    source: NutritionSource.fallback,
    label: 'Local fallback',
    provider: 'local-seed',
  );

  static const foods = [
    FoodItem(
      id: 'food-skyr',
      name: 'Plain skyr',
      servingDescription: '200 g bowl',
      nutritionPerServing: MacroTotals(
        calories: 150,
        proteinGrams: 22,
        carbsGrams: 12,
        fatGrams: 0.5,
      ),
      source: databaseSource,
    ),
    FoodItem(
      id: 'food-blueberries',
      name: 'Blueberries',
      servingDescription: '80 g handful',
      nutritionPerServing: MacroTotals(
        calories: 46,
        proteinGrams: 0.6,
        carbsGrams: 11,
        fatGrams: 0.2,
      ),
      source: databaseSource,
    ),
    FoodItem(
      id: 'food-chicken-salad',
      name: 'Chicken salad',
      servingDescription: '1 lunch bowl',
      nutritionPerServing: MacroTotals(
        calories: 520,
        proteinGrams: 42,
        carbsGrams: 38,
        fatGrams: 22,
      ),
      source: fallbackSource,
    ),
    FoodItem(
      id: 'food-banana',
      name: 'Banana',
      servingDescription: '1 medium banana',
      nutritionPerServing: MacroTotals(
        calories: 105,
        proteinGrams: 1.3,
        carbsGrams: 27,
        fatGrams: 0.4,
      ),
      source: fallbackSource,
    ),
    FoodItem(
      id: 'food-rolled-oats',
      name: 'Rolled oats',
      servingDescription: '50 g dry oats',
      nutritionPerServing: MacroTotals(
        calories: 185,
        proteinGrams: 6.5,
        carbsGrams: 30,
        fatGrams: 3.5,
      ),
      source: databaseSource,
    ),
    FoodItem(
      id: 'food-unknown-sauce',
      name: 'Unknown sauce',
      servingDescription: 'estimated spoonful',
      source: aiSource,
    ),
  ];

  static final meals = [
    Meal(
      id: 'meal-breakfast',
      name: 'Skyr bowl',
      eatenAt: DateTime(_seedDay.year, _seedDay.month, _seedDay.day, 8, 10),
      items: [
        MealItem(
          id: 'meal-breakfast-skyr',
          food: foods[0],
          servings: 1,
          source: userSource,
        ),
        MealItem(
          id: 'meal-breakfast-blueberries',
          food: foods[1],
          servings: 1,
          source: userSource,
        ),
      ],
      source: userSource,
    ),
    Meal(
      id: 'meal-lunch',
      name: 'Chicken salad',
      eatenAt: DateTime(_seedDay.year, _seedDay.month, _seedDay.day, 12, 35),
      items: [
        MealItem(
          id: 'meal-lunch-salad',
          food: foods[2],
          servings: 1,
          source: fallbackSource,
        ),
        MealItem(
          id: 'meal-lunch-sauce',
          food: foods[5],
          servings: 1,
          source: aiSource,
        ),
      ],
      source: userSource,
    ),
  ];

  static final weightEntries = [
    WeightEntry(
      id: 'weight-start',
      recordedAt: DateTime(_seedDay.year, _seedDay.month, _seedDay.day, 7),
      weightKg: 82.4,
      source: userSource,
    ),
  ];

  static const goal = NutritionGoal(
    proteinGrams: 110,
    calories: 2200,
    carbsGrams: 240,
    fatGrams: 75,
  );

  static const preferences = UserPreferences(
    primaryGoal: 'Build steady high-protein habits',
    dietaryPreferences: ['high protein'],
    dislikedFoods: ['raw onion'],
    coachingTone: 'calm and practical',
  );
}
