enum NutritionSource { aiEstimated, userConfirmed, databaseVerified, fallback }

class SourceMetadata {
  const SourceMetadata({
    required this.source,
    this.label,
    this.provider,
    this.confidence,
    this.observedAt,
  });

  final NutritionSource source;
  final String? label;
  final String? provider;
  final double? confidence;
  final DateTime? observedAt;

  bool get isVerified => source == NutritionSource.databaseVerified;

  SourceMetadata copyWith({
    NutritionSource? source,
    String? label,
    String? provider,
    double? confidence,
    DateTime? observedAt,
  }) {
    return SourceMetadata(
      source: source ?? this.source,
      label: label ?? this.label,
      provider: provider ?? this.provider,
      confidence: confidence ?? this.confidence,
      observedAt: observedAt ?? this.observedAt,
    );
  }
}

enum NutritionLookupStatus {
  verified,
  fallback,
  notFound,
  missingApiKey,
  providerError,
}

class NutritionLookupQuery {
  const NutritionLookupQuery({
    required this.foodName,
    this.barcode,
    this.servingDescription,
  });

  final String foodName;
  final String? barcode;
  final String? servingDescription;

  String get normalizedFoodName => normalizeFoodName(foodName);
}

class NutritionLookupResult {
  const NutritionLookupResult({
    required this.query,
    required this.status,
    required this.providerName,
    this.food,
    this.message,
  });

  final NutritionLookupQuery query;
  final NutritionLookupStatus status;
  final String providerName;
  final FoodItem? food;
  final String? message;

  bool get hasFood => food != null;

  bool get isVerified => status == NutritionLookupStatus.verified;

  bool get isFallback => status == NutritionLookupStatus.fallback;

  bool get isProviderUnavailable =>
      status == NutritionLookupStatus.missingApiKey ||
      status == NutritionLookupStatus.providerError;
}

class MealEnrichment {
  const MealEnrichment({required this.items, required this.lookupResults});

  final List<MealItem> items;
  final List<NutritionLookupResult> lookupResults;

  MacroTotals get knownMacroTotals => sumKnownMacros(items);

  int get itemsWithMissingNutrition =>
      items.where((item) => !item.hasKnownNutrition).length;

  bool get hasFallbackNutrition =>
      items.any((item) => item.food.source.source == NutritionSource.fallback);

  bool get hasUnverifiedAiNutrition => items.any(
    (item) =>
        item.source.source == NutritionSource.aiEstimated &&
        !item.food.source.isVerified,
  );
}

class MacroTotals {
  const MacroTotals({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  const MacroTotals.zero()
    : calories = 0,
      proteinGrams = 0,
      carbsGrams = 0,
      fatGrams = 0;

  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  MacroTotals operator +(MacroTotals other) {
    return MacroTotals(
      calories: calories + other.calories,
      proteinGrams: proteinGrams + other.proteinGrams,
      carbsGrams: carbsGrams + other.carbsGrams,
      fatGrams: fatGrams + other.fatGrams,
    );
  }

  MacroTotals scale(double factor) {
    return MacroTotals(
      calories: calories * factor,
      proteinGrams: proteinGrams * factor,
      carbsGrams: carbsGrams * factor,
      fatGrams: fatGrams * factor,
    );
  }
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.servingDescription,
    required this.source,
    this.nutritionPerServing,
    this.allergens = const [],
  });

  final String id;
  final String name;
  final String servingDescription;
  final MacroTotals? nutritionPerServing;
  final SourceMetadata source;
  final List<String> allergens;

  bool get hasKnownNutrition => nutritionPerServing != null;
}

class MealItem {
  const MealItem({
    required this.id,
    required this.food,
    required this.servings,
    required this.source,
    this.userNote,
    this.replacesEstimateId,
  });

  final String id;
  final FoodItem food;
  final double servings;
  final SourceMetadata source;
  final String? userNote;
  final String? replacesEstimateId;

  MacroTotals? get macroTotals => food.nutritionPerServing?.scale(servings);

  bool get hasKnownNutrition => macroTotals != null;

  MealItem copyWith({
    String? id,
    FoodItem? food,
    double? servings,
    SourceMetadata? source,
    String? userNote,
    String? replacesEstimateId,
  }) {
    return MealItem(
      id: id ?? this.id,
      food: food ?? this.food,
      servings: servings ?? this.servings,
      source: source ?? this.source,
      userNote: userNote ?? this.userNote,
      replacesEstimateId: replacesEstimateId ?? this.replacesEstimateId,
    );
  }

  MealItem userCorrected({
    required String id,
    required FoodItem food,
    double? servings,
    String? userNote,
  }) {
    return MealItem(
      id: id,
      food: food,
      servings: servings ?? this.servings,
      source: const SourceMetadata(
        source: NutritionSource.userConfirmed,
        label: 'User confirmed',
      ),
      userNote: userNote,
      replacesEstimateId: this.id,
    );
  }
}

class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.eatenAt,
    required this.items,
    required this.source,
    this.photoPath,
  });

  final String id;
  final String name;
  final DateTime eatenAt;
  final List<MealItem> items;
  final SourceMetadata source;
  final String? photoPath;

  MacroTotals get knownMacroTotals => sumKnownMacros(items);

  bool get hasMissingNutrition => items.any((item) => !item.hasKnownNutrition);
}

class MealEstimate {
  const MealEstimate({
    required this.id,
    required this.estimatedAt,
    required this.items,
    required this.source,
    this.photoPath,
  });

  final String id;
  final DateTime estimatedAt;
  final List<MealItem> items;
  final SourceMetadata source;
  final String? photoPath;

  Meal confirm({
    required String mealId,
    required String name,
    required DateTime eatenAt,
    List<MealItem>? correctedItems,
  }) {
    return Meal(
      id: mealId,
      name: name,
      eatenAt: eatenAt,
      items: correctedItems ?? items,
      source: const SourceMetadata(
        source: NutritionSource.userConfirmed,
        label: 'User confirmed meal',
      ),
      photoPath: photoPath,
    );
  }
}

class NutritionGoal {
  const NutritionGoal({
    required this.proteinGrams,
    this.calories,
    this.carbsGrams,
    this.fatGrams,
  });

  final double proteinGrams;
  final double? calories;
  final double? carbsGrams;
  final double? fatGrams;
}

class WeightGoal {
  const WeightGoal({this.targetWeightKg, this.weeklyChangeKg});

  final double? targetWeightKg;
  final double? weeklyChangeKg;
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
    required this.source,
  });

  final String id;
  final DateTime recordedAt;
  final double weightKg;
  final SourceMetadata source;
}

class UserPreferences {
  const UserPreferences({
    required this.primaryGoal,
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.dislikedFoods = const [],
    this.coachingTone = 'calm',
  });

  final String primaryGoal;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final List<String> dislikedFoods;
  final String coachingTone;
}

enum IngredientAvailability { available, runningLow, missing, unknown }

class KitchenInventoryItem {
  const KitchenInventoryItem({
    required this.food,
    required this.availability,
    required this.note,
    this.isFavorite = false,
    this.lastLoggedAt,
  });

  final FoodItem food;
  final IngredientAvailability availability;
  final String note;
  final bool isFavorite;
  final DateTime? lastLoggedAt;
}

class KitchenFavoriteMeal {
  const KitchenFavoriteMeal({
    required this.name,
    required this.timesLogged,
    required this.lastLoggedAt,
    required this.knownMacroTotals,
    required this.itemNames,
  });

  final String name;
  final int timesLogged;
  final DateTime lastLoggedAt;
  final MacroTotals knownMacroTotals;
  final List<String> itemNames;
}

class QuickLogSuggestion {
  const QuickLogSuggestion({
    required this.id,
    required this.title,
    required this.mealName,
    required this.food,
    required this.servings,
    required this.reason,
    required this.availability,
    required this.timeWindowLabel,
    required this.source,
  });

  final String id;
  final String title;
  final String mealName;
  final FoodItem food;
  final double servings;
  final String reason;
  final IngredientAvailability availability;
  final String timeWindowLabel;
  final SourceMetadata source;

  MacroTotals? get macroTotals => food.nutritionPerServing?.scale(servings);

  Meal toMeal({required DateTime eatenAt}) {
    final stamp = eatenAt.millisecondsSinceEpoch;
    return Meal(
      id: 'quick-log-$id-$stamp',
      name: mealName,
      eatenAt: eatenAt,
      items: [
        MealItem(
          id: 'quick-log-item-$id-$stamp',
          food: food,
          servings: servings,
          source: const SourceMetadata(
            source: NutritionSource.userConfirmed,
            label: 'Quick Log confirmed',
          ),
        ),
      ],
      source: const SourceMetadata(
        source: NutritionSource.userConfirmed,
        label: 'Quick Log confirmed meal',
      ),
    );
  }
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.meals,
    required this.knownMacroTotals,
    required this.itemsWithMissingNutrition,
    this.goal,
    this.latestWeightEntry,
    this.previousWeightEntry,
  });

  final DateTime date;
  final List<Meal> meals;
  final MacroTotals knownMacroTotals;
  final int itemsWithMissingNutrition;
  final NutritionGoal? goal;
  final WeightEntry? latestWeightEntry;
  final WeightEntry? previousWeightEntry;

  double? get proteinRemainingGrams {
    final goal = this.goal;
    if (goal == null) {
      return null;
    }
    final remaining = goal.proteinGrams - knownMacroTotals.proteinGrams;
    return remaining <= 0 ? 0 : remaining;
  }

  double? get calorieRemaining {
    final calories = goal?.calories;
    if (calories == null) {
      return null;
    }
    final remaining = calories - knownMacroTotals.calories;
    return remaining <= 0 ? 0 : remaining;
  }

  double? get proteinProgress {
    final goal = this.goal;
    if (goal == null || goal.proteinGrams <= 0) {
      return null;
    }
    return _progress(knownMacroTotals.proteinGrams, goal.proteinGrams);
  }

  double? get calorieProgress {
    final calories = goal?.calories;
    if (calories == null || calories <= 0) {
      return null;
    }
    return _progress(knownMacroTotals.calories, calories);
  }

  double? get carbsProgress {
    final carbs = goal?.carbsGrams;
    if (carbs == null || carbs <= 0) {
      return null;
    }
    return _progress(knownMacroTotals.carbsGrams, carbs);
  }

  double? get fatProgress {
    final fat = goal?.fatGrams;
    if (fat == null || fat <= 0) {
      return null;
    }
    return _progress(knownMacroTotals.fatGrams, fat);
  }

  double? get weightDeltaKg {
    final latest = latestWeightEntry;
    final previous = previousWeightEntry;
    if (latest == null || previous == null) {
      return null;
    }
    return latest.weightKg - previous.weightKg;
  }

  bool get hasMissingNutrition => itemsWithMissingNutrition > 0;

  bool get hasMeals => meals.isNotEmpty;
}

MacroTotals sumKnownMacros(Iterable<MealItem> items) {
  return items.fold(
    const MacroTotals.zero(),
    (total, item) => total + (item.macroTotals ?? const MacroTotals.zero()),
  );
}

DailySummary buildDailySummary({
  required DateTime date,
  required Iterable<Meal> meals,
  NutritionGoal? goal,
  Iterable<WeightEntry> weights = const [],
}) {
  final dayMeals =
      meals.where((meal) => _isSameDay(meal.eatenAt, date)).toList()
        ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  final allItems = dayMeals.expand((meal) => meal.items).toList();
  final dayWeights =
      weights
          .where((entry) => !entry.recordedAt.isAfter(_endOfDay(date)))
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  final latestWeight = dayWeights.firstOrNull;
  final previousWeight = dayWeights.skip(1).firstOrNull;

  return DailySummary(
    date: DateTime(date.year, date.month, date.day),
    meals: List.unmodifiable(dayMeals),
    knownMacroTotals: sumKnownMacros(allItems),
    itemsWithMissingNutrition: allItems
        .where((item) => !item.hasKnownNutrition)
        .length,
    goal: goal,
    latestWeightEntry: latestWeight,
    previousWeightEntry: previousWeight,
  );
}

double _progress(double value, double target) {
  final progress = value / target;
  if (progress < 0) {
    return 0;
  }
  if (progress > 1) {
    return 1;
  }
  return progress;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _endOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

String normalizeFoodName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<KitchenInventoryItem> buildKitchenInventory({
  required Iterable<FoodItem> foods,
  required Iterable<Meal> meals,
}) {
  final lastLoggedByFood = <String, DateTime>{};
  for (final meal in meals) {
    for (final item in meal.items) {
      final previous = lastLoggedByFood[item.food.id];
      if (previous == null || meal.eatenAt.isAfter(previous)) {
        lastLoggedByFood[item.food.id] = meal.eatenAt;
      }
    }
  }

  return foods
      .map(
        (food) => KitchenInventoryItem(
          food: food,
          availability: _availabilityForFood(food),
          note: _availabilityNote(food),
          isFavorite:
              lastLoggedByFood.containsKey(food.id) ||
              food.source.source == NutritionSource.databaseVerified,
          lastLoggedAt: lastLoggedByFood[food.id],
        ),
      )
      .toList(growable: false);
}

List<KitchenFavoriteMeal> buildFavoriteMeals(Iterable<Meal> meals) {
  final grouped = <String, List<Meal>>{};
  for (final meal in meals) {
    grouped.putIfAbsent(meal.name, () => []).add(meal);
  }

  final favorites = grouped.entries.map((entry) {
    final sorted = List<Meal>.of(entry.value)
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    final latest = sorted.first;
    return KitchenFavoriteMeal(
      name: entry.key,
      timesLogged: sorted.length,
      lastLoggedAt: latest.eatenAt,
      knownMacroTotals: latest.knownMacroTotals,
      itemNames: latest.items.map((item) => item.food.name).toList(),
    );
  }).toList()..sort((a, b) => b.lastLoggedAt.compareTo(a.lastLoggedAt));

  return favorites;
}

List<QuickLogSuggestion> buildQuickLogSuggestions({
  required DateTime now,
  required Iterable<FoodItem> foods,
  required Iterable<Meal> meals,
}) {
  final foodById = {for (final food in foods) food.id: food};
  final window = _timeWindow(now);
  final suggestions = <QuickLogSuggestion>[];

  final matchingHistory =
      meals.where((meal) => _timeWindow(meal.eatenAt) == window).toList()
        ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));

  for (final meal in matchingHistory) {
    for (final item in meal.items) {
      _addSuggestion(
        suggestions,
        food: item.food,
        mealName: meal.name,
        servings: item.servings,
        reason: 'Usually logged around ${_windowLabel(window).toLowerCase()}',
        window: window,
      );
    }
  }

  for (final foodId in _defaultFoodIdsForWindow(window)) {
    final food = foodById[foodId];
    if (food == null) {
      continue;
    }
    _addSuggestion(
      suggestions,
      food: food,
      mealName: _defaultMealName(food),
      servings: 1,
      reason: _defaultReasonForWindow(window),
      window: window,
    );
  }

  return suggestions.take(3).toList(growable: false);
}

void _addSuggestion(
  List<QuickLogSuggestion> suggestions, {
  required FoodItem food,
  required String mealName,
  required double servings,
  required String reason,
  required _MealTimeWindow window,
}) {
  if (suggestions.any((suggestion) => suggestion.food.id == food.id)) {
    return;
  }
  suggestions.add(
    QuickLogSuggestion(
      id: food.id,
      title: food.name,
      mealName: mealName,
      food: food,
      servings: servings,
      reason: reason,
      availability: _availabilityForFood(food),
      timeWindowLabel: _windowLabel(window),
      source: const SourceMetadata(
        source: NutritionSource.fallback,
        label: 'Habit suggestion',
        provider: 'local-history',
      ),
    ),
  );
}

enum _MealTimeWindow { morning, midday, afternoon, evening, late }

_MealTimeWindow _timeWindow(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 11) {
    return _MealTimeWindow.morning;
  }
  if (hour >= 11 && hour < 15) {
    return _MealTimeWindow.midday;
  }
  if (hour >= 15 && hour < 18) {
    return _MealTimeWindow.afternoon;
  }
  if (hour >= 18 && hour < 22) {
    return _MealTimeWindow.evening;
  }
  return _MealTimeWindow.late;
}

List<String> _defaultFoodIdsForWindow(_MealTimeWindow window) {
  return switch (window) {
    _MealTimeWindow.morning => ['food-skyr', 'food-rolled-oats'],
    _MealTimeWindow.midday => ['food-chicken-salad', 'food-banana'],
    _MealTimeWindow.afternoon => ['food-banana', 'food-skyr'],
    _MealTimeWindow.evening => ['food-chicken-salad', 'food-rolled-oats'],
    _MealTimeWindow.late => ['food-skyr', 'food-banana'],
  };
}

String _windowLabel(_MealTimeWindow window) {
  return switch (window) {
    _MealTimeWindow.morning => 'Morning',
    _MealTimeWindow.midday => 'Midday',
    _MealTimeWindow.afternoon => 'Afternoon',
    _MealTimeWindow.evening => 'Evening',
    _MealTimeWindow.late => 'Late',
  };
}

String _defaultReasonForWindow(_MealTimeWindow window) {
  return switch (window) {
    _MealTimeWindow.morning => 'Fits a common high-protein morning',
    _MealTimeWindow.midday => 'Fits the usual lunch window',
    _MealTimeWindow.afternoon => 'Good for a light afternoon snack',
    _MealTimeWindow.evening => 'Keeps dinner simple from familiar foods',
    _MealTimeWindow.late => 'Light option for a late check-in',
  };
}

String _defaultMealName(FoodItem food) {
  return switch (food.id) {
    'food-skyr' => 'Skyr bowl',
    'food-chicken-salad' => 'Chicken salad',
    'food-banana' => 'Banana snack',
    'food-rolled-oats' => 'Oats bowl',
    _ => food.name,
  };
}

IngredientAvailability _availabilityForFood(FoodItem food) {
  return switch (food.source.source) {
    NutritionSource.databaseVerified => IngredientAvailability.available,
    NutritionSource.userConfirmed => IngredientAvailability.available,
    NutritionSource.fallback => IngredientAvailability.runningLow,
    NutritionSource.aiEstimated => IngredientAvailability.unknown,
  };
}

String _availabilityNote(FoodItem food) {
  return switch (_availabilityForFood(food)) {
    IngredientAvailability.available => 'Available in kitchen',
    IngredientAvailability.runningLow => 'Check quantity before relying on it',
    IngredientAvailability.missing => 'Not currently available',
    IngredientAvailability.unknown => 'Availability not confirmed yet',
  };
}
