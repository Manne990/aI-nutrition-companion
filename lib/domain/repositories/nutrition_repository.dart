import '../models/nutrition.dart';
import '../services/nutrition_lookup_service.dart';
import '../../services/adapters/nutrition_lookup_adapters.dart';

abstract interface class NutritionRepository {
  List<FoodItem> foods();

  List<Meal> meals();

  List<WeightEntry> weightEntries();

  NutritionGoal nutritionGoal();

  UserPreferences userPreferences();

  DailySummary dailySummary(DateTime date);

  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query);

  Future<MealEnrichment> enrichMealItems(List<MealItem> items);

  Future<MealEstimate> enrichMealEstimate(MealEstimate estimate);

  Meal saveMeal(Meal meal);

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
  WeightEntry saveWeightEntry(WeightEntry entry) {
    _weightEntries.removeWhere((existing) => existing.id == entry.id);
    _weightEntries.add(entry);
    _weightEntries.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return entry;
  }
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
