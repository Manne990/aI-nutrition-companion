import 'package:ai_nutrition_companion/app/ai_nutrition_companion_app.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/health_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/onboarding_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OnboardingProfile _profile() {
  return OnboardingProfile(
    primaryGoal: 'Build steady high-protein habits',
    proteinGoalGrams: 110,
    dietaryPreferences: const ['high protein'],
    coachingTone: 'calm and practical',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  InMemoryOnboardingRepository? repository,
  NutritionRepository? nutritionRepository,
}) async {
  await tester.pumpWidget(
    AiNutritionCompanionApp(
      onboardingRepository:
          repository ?? InMemoryOnboardingRepository(_profile()),
      aiSettingsRepository: InMemoryAiSettingsRepository(),
      authRepository: InMemoryAuthRepository(),
      healthRepository: InMemoryHealthRepository(),
      aiChatRepository: InMemoryAiChatRepository(),
      nutritionRepository: nutritionRepository ?? InMemoryNutritionRepository(),
    ),
  );
  await tester.pumpAndSettle();
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

void main() {
  testWidgets('returning user sees Today and bottom navigation', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(find.text('Daily overview'), findsOneWidget);
    expect(find.text('110g protein goal'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('Skyr bowl with berries'));

    expect(find.text('Skyr bowl with berries'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between V1 sections', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('AI provider'), findsOneWidget);
  });

  testWidgets('Today and Kitchen share saved nutrition state', (tester) async {
    final nutritionRepository = InMemoryNutritionRepository();

    await _pumpApp(tester, nutritionRepository: nutritionRepository);

    await _scrollUntilVisible(tester, find.text('Banana snack'));
    final bananaSuggestion = find.ancestor(
      of: find.text('Banana snack'),
      matching: find.byType(DecoratedBox),
    );
    final bananaLogButton = find.descendant(
      of: bananaSuggestion,
      matching: find.widgetWithText(FilledButton, 'Log'),
    );
    await tester.ensureVisible(bananaLogButton);
    await tester.pumpAndSettle();

    await tester.tap(bananaLogButton);
    await tester.pumpAndSettle();

    expect(nutritionRepository.meals().last.name, 'Banana snack');

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);
    expect(find.text('Banana snack'), findsOneWidget);
  });

  testWidgets('first-run user can skip optional steps and complete consent', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository();

    await _pumpApp(tester, repository: repository);

    expect(find.text('Set your direction'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Food boundaries'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Targets and tone'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Consent boundaries'), findsOneWidget);
    expect(find.text('Start Today'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.tap(find.byType(CheckboxListTile).at(2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Today'));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect((await repository.loadProfile())?.hasRequiredConsent, isTrue);
  });

  testWidgets(
    'reset onboarding clears local profile for tests and development',
    (tester) async {
      final repository = InMemoryOnboardingRepository(_profile());

      await _pumpApp(tester, repository: repository);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(tester, find.text('Reset onboarding'));
      await tester.tap(find.text('Reset onboarding'));
      await tester.pumpAndSettle();

      expect(await repository.loadProfile(), isNull);
      expect(find.text('Set your direction'), findsOneWidget);
    },
  );
}
