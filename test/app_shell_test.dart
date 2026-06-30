import 'package:ai_nutrition_companion/app/ai_nutrition_companion_app.dart';
import 'package:ai_nutrition_companion/app/service_credentials.dart';
import 'package:ai_nutrition_companion/domain/models/auth.dart';
import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/health_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/onboarding_repository.dart';
import 'package:ai_nutrition_companion/services/adapters/nutrition_lookup_adapters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _searchGenericFood(WidgetTester tester, String foodName) async {
  await _scrollUntilVisible(tester, _textFieldWithLabel('Food name'));
  await tester.enterText(_textFieldWithLabel('Food name'), foodName);
  await _scrollUntilVisible(tester, find.text('Search generic food'));
  await tester.tap(find.text('Search generic food'));
  await tester.pumpAndSettle();
}

class _RuntimeFoodDataCentralSearchClient
    implements FoodDataCentralSearchClient {
  final apiKeys = <String>[];
  final queries = <String>[];

  @override
  Future<FoodDataCentralSearchResponse> searchFoods({
    required String query,
    required String apiKey,
  }) async {
    apiKeys.add(apiKey);
    queries.add(query);
    return FoodDataCentralSearchResponse.fromJson({
      'foods': [
        {
          'fdcId': '${apiKeys.length}${query.length}',
          'description': '$query verified',
          'servingSize': 100,
          'servingSizeUnit': 'g',
          'foodNutrients': [
            {'nutrientId': 1008, 'nutrientName': 'Energy', 'value': 180},
            {'nutrientId': 1003, 'nutrientName': 'Protein', 'value': 20},
            {'nutrientId': 1005, 'nutrientName': 'Carbohydrate', 'value': 3},
            {
              'nutrientId': 1004,
              'nutrientName': 'Total lipid (fat)',
              'value': 9,
            },
          ],
        },
      ],
    });
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  InMemoryOnboardingRepository? repository,
  AiSettingsRepository? aiSettingsRepository,
  AuthRepository? authRepository,
  HealthRepository? healthRepository,
  NutritionRepository? nutritionRepository,
  FoodDataCentralSearchClient? foodDataCentralSearchClient,
  AppServiceCredentials serviceCredentials = const AppServiceCredentials(),
  bool useDefaultNutritionRepository = false,
  DateTime? now,
}) async {
  await tester.pumpWidget(
    AiNutritionCompanionApp(
      onboardingRepository:
          repository ?? InMemoryOnboardingRepository(_profile()),
      aiSettingsRepository:
          aiSettingsRepository ?? InMemoryAiSettingsRepository(),
      authRepository:
          authRepository ??
          InMemoryAuthRepository(
            initialState: const AuthAccountState(
              status: AuthConnectionStatus.signedIn,
              provider: AuthProvider.local,
              userLabel: 'Returning user',
            ),
          ),
      healthRepository: healthRepository ?? InMemoryHealthRepository(),
      aiChatRepository: InMemoryAiChatRepository(),
      nutritionRepository: useDefaultNutritionRepository
          ? nutritionRepository
          : nutritionRepository ?? InMemoryNutritionRepository(),
      serviceCredentials: serviceCredentials,
      foodDataCentralSearchClient: foodDataCentralSearchClient,
      now: now ?? DateTime(2026, 6, 29, 15, 30),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
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

void main() {
  testWidgets('fresh launch shows account entry before product tabs', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      authRepository: InMemoryAuthRepository(),
      repository: InMemoryOnboardingRepository(_profile()),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('What should I eat next?'), findsNothing);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Kitchen'), findsNothing);
    expect(find.text('Me'), findsNothing);
  });

  testWidgets('sign in requires an existing local account', (tester) async {
    await _pumpApp(
      tester,
      authRepository: InMemoryAuthRepository(),
      repository: InMemoryOnboardingRepository(_profile()),
    );

    await tester.enterText(_textFieldWithLabel('Email'), 'person@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('No local account exists yet. Register first.'),
      findsOneWidget,
    );
    expect(find.text('What should I eat next?'), findsNothing);
  });

  testWidgets('sign in rejects credentials for a different local account', (
    tester,
  ) async {
    final authRepository = InMemoryAuthRepository(
      initialAccount: LocalAccountRecord(
        email: 'saved@example.com',
        displayName: 'Saved Person',
        createdAt: DateTime(2026, 6, 29),
      ),
    );

    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: InMemoryOnboardingRepository(_profile()),
    );

    await tester.enterText(_textFieldWithLabel('Email'), 'wrong@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('No local account matches that email.'), findsOneWidget);
    expect(find.text('What should I eat next?'), findsNothing);
  });

  testWidgets('existing local account can sign in to product tabs', (
    tester,
  ) async {
    final authRepository = InMemoryAuthRepository(
      initialAccount: LocalAccountRecord(
        email: 'saved@example.com',
        displayName: 'Saved Person',
        createdAt: DateTime(2026, 6, 29),
      ),
    );

    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: InMemoryOnboardingRepository(_profile()),
    );

    await tester.enterText(_textFieldWithLabel('Email'), 'saved@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('register creates a local account and starts onboarding', (
    tester,
  ) async {
    final authRepository = InMemoryAuthRepository();
    final repository = InMemoryOnboardingRepository();

    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: repository,
    );

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(_textFieldWithLabel('Email'), 'new@example.com');
    await tester.enterText(_textFieldWithLabel('Name'), 'New Person');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Set your direction'), findsOneWidget);
    expect((await authRepository.loadState()).isSignedIn, isTrue);
    expect(
      (await authRepository.loadLocalAccount())?.normalizedEmail,
      'new@example.com',
    );
  });

  testWidgets('logout returns to account entry and blocks product tabs', (
    tester,
  ) async {
    final authRepository = InMemoryAuthRepository(
      initialState: const AuthAccountState(
        status: AuthConnectionStatus.signedIn,
        provider: AuthProvider.local,
        userLabel: 'Signed User',
      ),
      initialAccount: LocalAccountRecord(
        email: 'signed@example.com',
        displayName: 'Signed User',
        createdAt: DateTime(2026, 6, 29),
      ),
    );

    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: InMemoryOnboardingRepository(_profile()),
    );

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await _scrollUntilVisible(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('AI Nutrition Companion'), findsOneWidget);
    expect(find.text('What should I eat next?'), findsNothing);
    expect(find.text('Today'), findsNothing);
  });

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

  testWidgets('Today and Kitchen restore persisted nutrition progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesNutritionRepository(
      preferences,
      seedMeals: const [],
      seedWeightEntries: const [],
    );
    repository.saveMeal(
      Meal(
        id: 'persisted-banana',
        name: 'Persisted banana snack',
        eatenAt: DateTime(2026, 6, 29, 15),
        items: [
          MealItem(
            id: 'persisted-banana-item',
            food: NutritionSeedData.foods.firstWhere(
              (food) => food.id == 'food-banana',
            ),
            servings: 1,
            source: NutritionSeedData.userSource,
          ),
        ],
        source: NutritionSeedData.userSource,
      ),
    );
    await repository.flushPendingWrites();

    await _pumpApp(tester, useDefaultNutritionRepository: true);

    await _scrollUntilVisible(tester, find.text('Persisted banana snack'));
    expect(find.text('Persisted banana snack'), findsOneWidget);
    expect(find.text('105 kcal | 1g protein'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorite meals'), findsOneWidget);
    expect(find.text('Persisted banana snack'), findsOneWidget);
  });

  testWidgets('configured FoodData Central key enables runtime lookup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final foodDataCentralClient = _RuntimeFoodDataCentralSearchClient();

    await _pumpApp(
      tester,
      useDefaultNutritionRepository: true,
      serviceCredentials: const AppServiceCredentials(
        foodDataCentralApiKey: 'configured-build-key',
      ),
      foodDataCentralSearchClient: foodDataCentralClient,
    );

    await _searchGenericFood(tester, 'salmon');

    expect(foodDataCentralClient.apiKeys, ['configured-build-key']);
    expect(find.text('salmon verified'), findsOneWidget);
    expect(
      find.text('Matched FoodData Central search nutrition.'),
      findsOneWidget,
    );
  });

  testWidgets('missing FoodData Central app key degrades gracefully', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final foodDataCentralClient = _RuntimeFoodDataCentralSearchClient();

    await _pumpApp(
      tester,
      useDefaultNutritionRepository: true,
      serviceCredentials: const AppServiceCredentials(
        foodDataCentralApiKey: '',
      ),
      foodDataCentralSearchClient: foodDataCentralClient,
    );

    await _searchGenericFood(tester, 'avocado');

    expect(foodDataCentralClient.apiKeys, isEmpty);
    expect(find.text('FoodData Central unavailable'), findsOneWidget);
    expect(
      find.text(
        'FoodData Central lookup is not configured for this build. Open Food Facts and local fallback nutrition remain available.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('first-run user can skip optional steps and complete consent', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository();
    final healthRepository = InMemoryHealthRepository();

    await _pumpApp(
      tester,
      repository: repository,
      healthRepository: healthRepository,
    );

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
    await tester.tap(find.text('Allow backup'));
    await tester.pumpAndSettle();
    await _scrollUntilVisible(
      tester,
      find.text('Connect Health for nutrition context.'),
    );
    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'Connect Health for nutrition context.',
      ),
    );
    await tester.pumpAndSettle();

    await _scrollUntilVisible(
      tester,
      find.text('I understand nutrition guidance is not medical advice.'),
    );
    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'I understand nutrition guidance is not medical advice.',
      ),
    );
    await _scrollUntilVisible(
      tester,
      find.text('I understand AI meal and macro estimates may be uncertain.'),
    );
    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'I understand AI meal and macro estimates may be uncertain.',
      ),
    );
    await _scrollUntilVisible(
      tester,
      find.text(
        'Camera, health, and token access stay off until I choose a feature that needs them.',
      ),
    );
    await tester.tap(
      find.widgetWithText(
        CheckboxListTile,
        'Camera, health, and token access stay off until I choose a feature that needs them.',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Today'));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    final profile = await repository.loadProfile();
    expect(profile?.hasRequiredConsent, isTrue);
    expect(
      profile?.backupPreference,
      LocalDataBackupPreference.platformBackupAllowed,
    );
    expect(profile?.healthConnectionApproved, isTrue);
    expect(
      (await healthRepository.loadState()).status,
      HealthConnectionStatus.connected,
    );

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await _scrollUntilVisible(tester, find.text('Health connection'));
    expect(find.text('Connected'), findsOneWidget);
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
