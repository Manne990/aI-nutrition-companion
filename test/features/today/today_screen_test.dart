import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/meal_suggestion.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/features/today/today_screen.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_companion_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(ListView);
  for (var attempt = 0; attempt < 12; attempt += 1) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

class _FixtureAdapter implements NutritionCompanionAdapter {
  const _FixtureAdapter(this.suggestions);

  final List<MealSuggestion> suggestions;

  @override
  List<MealSuggestion> mealSuggestions({UserPreferences? preferences}) {
    return suggestions;
  }
}

void main() {
  final profile = OnboardingProfile(
    primaryGoal: 'Build steady high-protein habits',
    proteinGoalGrams: 110,
    dietaryPreferences: const ['high protein'],
    coachingTone: 'calm and practical',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29),
  );

  const firstSuggestion = MealSuggestion(
    title: 'Skyr bowl with berries',
    summary: 'Quick protein with fruit and a gentle texture.',
    proteinGrams: 32,
    calories: 410,
    prepMinutes: 6,
    ingredientAvailability: 'All ingredients available',
    nutritionRationale: 'Closes most of today protein gap',
    source: NutritionSource.aiEstimated,
    imageAssetKey: 'fixture-skyr-bowl',
  );

  const secondSuggestion = MealSuggestion(
    title: 'Chicken salad wrap',
    summary: 'Uses lunch ingredients and keeps dinner flexible.',
    proteinGrams: 38,
    calories: 520,
    prepMinutes: 12,
    ingredientAvailability: 'Chicken and greens ready',
    nutritionRationale: 'Adds lean protein without a heavy meal',
    source: NutritionSource.fallback,
    imageAssetKey: 'fixture-chicken-wrap',
  );

  testWidgets('renders Today recommendation, rhythm, and AI insight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
        ),
      ),
    );

    expect(find.text('Monday, June 29'), findsOneWidget);
    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text('Today focus: Build steady high-protein habits.'),
      findsOneWidget,
    );
    expect(find.text('Today rhythm'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('2h 55m ago'), findsOneWidget);
    expect(find.text('45g left'), findsOneWidget);
    expect(find.text('Daily overview'), findsOneWidget);
    expect(find.text('65 / 110 g'), findsOneWidget);
    expect(find.text('716 / 2200 kcal'), findsOneWidget);
    expect(find.text('Needs confirmation'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

    expect(find.text('Skyr bowl with berries'), findsOneWidget);
    expect(find.text('6 min prep'), findsOneWidget);
    expect(find.text('All ingredients available'), findsOneWidget);
    expect(find.text('Closes most of today protein gap'), findsOneWidget);
    expect(find.text('AI-estimated'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('You are about 45g short'),
    );

    expect(find.textContaining('You are about 45g short'), findsOneWidget);
  });

  testWidgets('suggestion actions update visible local state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Accept suggestion'));
    await tester.tap(find.text('Accept suggestion'));
    await tester.pumpAndSettle();

    expect(find.text('Accepted Skyr bowl with berries'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Change'));
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken salad wrap'), findsOneWidget);
    expect(find.text('Changed to Chicken salad wrap'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Deferred for later'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Explain why'));
    await tester.tap(find.text('Explain why'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Because adds lean protein without a heavy meal and chicken and greens ready.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty fixture data renders a graceful Today state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: const _FixtureAdapter([]),
          repository: InMemoryNutritionRepository(seedMeals: const []),
        ),
      ),
    );

    expect(find.text('No meals yet'), findsOneWidget);
    expect(find.text('No sources yet'), findsOneWidget);
    expect(find.text('0 / 110 g'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('No meal suggestion ready'));

    expect(find.text('No meal suggestion ready'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('No meals logged yet today'),
    );

    expect(find.textContaining('No meals logged yet today'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('I do not have a suggestion yet'),
    );

    expect(
      find.textContaining('I do not have a suggestion yet'),
      findsOneWidget,
    );
  });

  testWidgets('weight entry persists locally and updates trend display', (
    tester,
  ) async {
    final repository = InMemoryNutritionRepository(
      seedWeightEntries: [
        WeightEntry(
          id: 'yesterday',
          recordedAt: DateTime(2026, 6, 28, 7),
          weightKg: 82.4,
          source: NutritionSeedData.userSource,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: repository,
          now: DateTime(2026, 6, 29, 15, 30),
        ),
      ),
    );

    await _scrollUntilVisible(tester, find.text('Add weight'));
    await tester.enterText(find.byType(TextField), '81.9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.weightEntries(), hasLength(2));
    expect(find.textContaining('81.9 kg'), findsOneWidget);
    expect(find.textContaining('Down 0.5 kg'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.text('Weight saved. Trend updated for today.'),
    );

    expect(find.text('Weight saved. Trend updated for today.'), findsOneWidget);
  });

  testWidgets('completed day state keeps guidance actionable', (tester) async {
    final repository = InMemoryNutritionRepository(
      seedMeals: [NutritionSeedData.meals.first],
      seedGoal: const NutritionGoal(
        proteinGrams: 20,
        calories: 180,
        carbsGrams: 20,
        fatGrams: 1,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        TodayScreen(
          profile: profile,
          adapter: _FixtureAdapter([firstSuggestion]),
          repository: repository,
        ),
      ),
    );

    expect(find.text('23 / 20 g'), findsWidgets);
    expect(find.textContaining('Protein goal met'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('Your protein target is covered'),
    );

    expect(
      find.textContaining('Your protein target is covered'),
      findsOneWidget,
    );
  });

  testWidgets('Today fits small and large mobile constraints', (tester) async {
    for (final size in const [Size(320, 720), Size(430, 932)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        _wrap(
          TodayScreen(
            profile: profile,
            adapter: _FixtureAdapter([firstSuggestion, secondSuggestion]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('What should I eat next?'), findsOneWidget);

      await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

      expect(find.text('Skyr bowl with berries'), findsOneWidget);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
