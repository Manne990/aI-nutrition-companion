import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/features/photo_logging/photo_meal_logging_card.dart';
import 'package:ai_nutrition_companion/services/adapters/meal_recognition_adapter.dart';
import 'package:ai_nutrition_companion/services/photo/photo_meal_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SafeArea(child: SingleChildScrollView(child: child)),
    ),
  );
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _FixturePhotoSource implements PhotoMealSource {
  const _FixturePhotoSource({this.capture, this.error});

  final PhotoMealCapture? capture;
  final PhotoMealCaptureException? error;

  @override
  Future<PhotoMealCapture?> pickPhoto(PhotoMealCaptureMode mode) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return capture;
  }
}

class _ScriptedNutritionRepository extends InMemoryNutritionRepository {
  _ScriptedNutritionRepository({required this.lookup});

  final Future<NutritionLookupResult> Function(NutritionLookupQuery query)
  lookup;

  @override
  Future<NutritionLookupResult> lookupFood(NutritionLookupQuery query) {
    return lookup(query);
  }
}

void main() {
  test('mock meal recognition returns deterministic AI estimate', () async {
    const adapter = MockMealRecognitionAdapter();

    final estimate = await adapter.estimateMealFromPhoto(
      const PhotoMealCapture(
        path: '/tmp/grain-bowl.jpg',
        mode: PhotoMealCaptureMode.camera,
      ),
    );

    expect(estimate.photoPath, '/tmp/grain-bowl.jpg');
    expect(estimate.source.source, NutritionSource.aiEstimated);
    expect(estimate.source.provider, 'mock-photo-ai');
    expect(estimate.items.map((item) => item.food.name), [
      'Chicken grain bowl',
      'Creamy dressing',
    ]);
    expect(estimate.items.first.macroTotals?.calories, 610);
  });

  testWidgets('reviews corrects removes adds and saves a confirmed meal', (
    tester,
  ) async {
    final repository = InMemoryNutritionRepository(seedMeals: const []);

    await tester.pumpWidget(
      _wrap(
        PhotoMealLoggingCard(
          repository: repository,
          photoSource: const _FixturePhotoSource(
            capture: PhotoMealCapture(
              path: '/tmp/test-meal.jpg',
              mode: PhotoMealCaptureMode.gallery,
            ),
          ),
          now: DateTime(2026, 6, 29, 18),
        ),
      ),
    );

    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(find.text('Review estimate'), findsOneWidget);
    expect(find.text('Chicken grain bowl'), findsOneWidget);
    expect(find.text('Creamy dressing'), findsOneWidget);
    expect(find.text('730'), findsOneWidget);
    expect(
      find.text(
        'AI estimate ready. Values stay estimated until you confirm them.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('photo-meal-servings-estimate-chicken-bowl')),
      '0.5',
    );
    await tester.pumpAndSettle();

    expect(find.text('425'), findsOneWidget);

    final removeDressing = find.byTooltip('Remove Creamy dressing');
    await _ensureVisible(tester, removeDressing);
    await tester.tap(removeDressing);
    await tester.pumpAndSettle();
    await _ensureVisible(tester, find.text('Add item'));
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    expect(find.text('405'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('photo-meal-name-manual-3')),
      'Protein shake',
    );
    await tester.pumpAndSettle();
    await _ensureVisible(tester, find.text('Save confirmed meal'));
    await tester.tap(find.text('Save confirmed meal'));
    await tester.pumpAndSettle();

    final savedMeal = repository.meals().single;
    expect(savedMeal.name, 'Photo meal');
    expect(savedMeal.photoPath, '/tmp/test-meal.jpg');
    expect(savedMeal.source.source, NutritionSource.userConfirmed);
    expect(savedMeal.items, hasLength(2));
    expect(savedMeal.items.first.replacesEstimateId, 'estimate-chicken-bowl');
    expect(savedMeal.items.first.source.source, NutritionSource.userConfirmed);
    expect(savedMeal.items.first.servings, 0.5);
    expect(savedMeal.items.last.food.name, 'Protein shake');
    expect(savedMeal.knownMacroTotals.calories, 405);
    expect(
      find.text('Saved Photo meal with 2 confirmed items'),
      findsOneWidget,
    );
  });

  testWidgets('looks up and saves packaged food with source metadata', (
    tester,
  ) async {
    late NutritionLookupQuery capturedQuery;
    final repository = _ScriptedNutritionRepository(
      lookup: (query) async {
        capturedQuery = query;
        return NutritionLookupResult(
          query: query,
          status: NutritionLookupStatus.verified,
          providerName: 'open-food-facts',
          food: const FoodItem(
            id: 'off-737628064502',
            name: 'Packaged skyr cup',
            servingDescription: '150 g cup',
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
              confidence: 0.95,
            ),
          ),
          message: 'Matched packaged product nutrition by barcode.',
        );
      },
    );

    await tester.pumpWidget(
      _wrap(
        PhotoMealLoggingCard(
          repository: repository,
          now: DateTime(2026, 6, 29, 19),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '737628064502');
    await tester.tap(find.text('Look up package'));
    await tester.pumpAndSettle();

    expect(capturedQuery.barcode, '737628064502');
    expect(find.text('Packaged skyr cup'), findsOneWidget);
    expect(find.text('Open Food Facts'), findsOneWidget);
    expect(find.text('Verified source'), findsOneWidget);
    expect(
      find.text('Matched packaged product nutrition by barcode.'),
      findsOneWidget,
    );

    await _ensureVisible(tester, find.text('Save packaged food'));
    await tester.tap(find.text('Save packaged food'));
    await tester.pumpAndSettle();

    final savedMeal = repository.meals().last;
    expect(savedMeal.name, 'Packaged skyr cup');
    expect(savedMeal.source.source, NutritionSource.userConfirmed);
    expect(savedMeal.items.single.food.source.provider, 'open-food-facts');
    expect(savedMeal.items.single.food.source.isVerified, isTrue);
    expect(savedMeal.knownMacroTotals.proteinGrams, 18);
    expect(find.text('Packaged food saved to today.'), findsOneWidget);
  });

  testWidgets(
    'represents packaged lookup not found provider error and fallback',
    (tester) async {
      final scriptedResults =
          <NutritionLookupResult Function(NutritionLookupQuery)>[
            (query) => NutritionLookupResult(
              query: query,
              status: NutritionLookupStatus.notFound,
              providerName: 'open-food-facts',
              message: 'No Open Food Facts product matched barcode 000.',
            ),
            (query) => NutritionLookupResult(
              query: query,
              status: NutritionLookupStatus.providerError,
              providerName: 'open-food-facts',
              message: 'Open Food Facts returned malformed nutrition data.',
            ),
            (query) => NutritionLookupResult(
              query: query,
              status: NutritionLookupStatus.fallback,
              providerName: 'local-fallback',
              food: const FoodItem(
                id: 'local-bar',
                name: 'Fallback protein bar',
                servingDescription: '1 bar',
                nutritionPerServing: MacroTotals(
                  calories: 210,
                  proteinGrams: 12,
                  carbsGrams: 22,
                  fatGrams: 7,
                ),
                source: SourceMetadata(
                  source: NutritionSource.fallback,
                  label: 'Local fallback',
                  provider: 'local-fallback',
                ),
              ),
              message:
                  'Matched local fallback nutrition; confirm if precision matters.',
            ),
          ];
      var lookupIndex = 0;
      final repository = _ScriptedNutritionRepository(
        lookup: (query) async => scriptedResults[lookupIndex++](query),
      );

      await tester.pumpWidget(
        _wrap(PhotoMealLoggingCard(repository: repository)),
      );

      await tester.enterText(find.byType(TextField), '000');
      await tester.tap(find.text('Look up package'));
      await tester.pumpAndSettle();

      expect(
        find.text('No Open Food Facts product matched barcode 000.'),
        findsOneWidget,
      );
      expect(find.text('No packaged match'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '111');
      await tester.tap(find.text('Look up package'));
      await tester.pumpAndSettle();

      expect(
        find.text('Open Food Facts returned malformed nutrition data.'),
        findsOneWidget,
      );
      expect(find.text('Provider unavailable'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '222');
      await tester.tap(find.text('Look up package'));
      await tester.pumpAndSettle();

      expect(find.text('Fallback protein bar'), findsOneWidget);
      expect(find.text('Local fallback'), findsOneWidget);
      expect(find.text('Source gap fallback'), findsOneWidget);
      expect(
        find.text(
          'Matched local fallback nutrition; confirm if precision matters.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('permission denial leaves usable retry actions', (tester) async {
    final repository = InMemoryNutritionRepository(seedMeals: const []);

    await tester.pumpWidget(
      _wrap(
        PhotoMealLoggingCard(
          repository: repository,
          photoSource: const _FixturePhotoSource(
            error: PhotoMealCaptureException(
              PhotoMealCaptureFailureKind.permissionDenied,
              'Camera permission is denied. You can choose another source or keep logging manually.',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Camera permission is denied. You can choose another source or keep logging manually.',
      ),
      findsOneWidget,
    );
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(repository.meals(), isEmpty);
  });
}
