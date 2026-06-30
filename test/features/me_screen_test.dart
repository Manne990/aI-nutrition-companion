import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/auth.dart';
import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/health_repository.dart';
import 'package:ai_nutrition_companion/features/me/me_screen.dart';
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

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _pumpMe(
  WidgetTester tester,
  InMemoryAiSettingsRepository aiRepository, {
  InMemoryAuthRepository? authRepository,
  AuthAccountState authState = AuthAccountState.signedOut,
  InMemoryHealthRepository? healthRepository,
  HealthConnectionState healthState = HealthConnectionState.disconnected,
}) async {
  final effectiveAuthRepository =
      authRepository ?? InMemoryAuthRepository(initialState: authState);
  final effectiveHealthRepository =
      healthRepository ?? InMemoryHealthRepository(initialState: healthState);
  await tester.pumpWidget(
    _wrap(
      MeScreen(
        profile: _profile(),
        aiSettingsRepository: aiRepository,
        authRepository: effectiveAuthRepository,
        authState: authState,
        healthRepository: effectiveHealthRepository,
        healthState: healthState,
        onAiSettingsChanged: () async {},
        onAuthStateChanged: () async {},
        onHealthStateChanged: () async {},
        onResetOnboarding: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openProviderMenu(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<AiProvider>));
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(ListView);
  for (var attempt = 0; attempt < 8; attempt += 1) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets('AI settings default to mock mode without token', (tester) async {
    final repository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, repository);

    expect(find.text('AI provider'), findsOneWidget);
    expect(find.text('Mock AI'), findsOneWidget);
    expect(find.text('mock-companion-v1'), findsOneWidget);
    expect(find.text('No token saved'), findsOneWidget);
    expect(find.text('No FoodData Central key'), findsOneWidget);
    expect(find.text('Secure local storage'), findsWidgets);
    expect(
      find.textContaining('Mock AI is the default for tests and local CI'),
      findsOneWidget,
    );
  });

  testWidgets('account state starts signed out with mock auth boundary', (
    tester,
  ) async {
    final repository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, repository);
    await _scrollUntilVisible(tester, find.text('Account'));

    expect(find.text('Signed out'), findsOneWidget);
    expect(find.text('Mock local auth'), findsOneWidget);
    expect(find.text('Use mock account'), findsOneWidget);
    expect(find.textContaining('Nutrition logs remain local'), findsOneWidget);
  });

  testWidgets('user can sign in and out of mock local auth', (tester) async {
    final aiRepository = InMemoryAiSettingsRepository();
    final authRepository = InMemoryAuthRepository();

    await _pumpMe(tester, aiRepository, authRepository: authRepository);
    await _scrollUntilVisible(tester, find.text('Use mock account'));
    await tester.tap(find.text('Use mock account'));
    await tester.pumpAndSettle();

    expect(
      (await authRepository.loadState()).status,
      AuthConnectionStatus.signedIn,
    );
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Local mock user'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(
      (await authRepository.loadState()).status,
      AuthConnectionStatus.signedOut,
    );
    expect(find.text('Signed out'), findsOneWidget);
  });

  testWidgets('provider-unavailable auth state is visible without secrets', (
    tester,
  ) async {
    final aiRepository = InMemoryAiSettingsRepository();
    const unavailableState = AuthAccountState(
      status: AuthConnectionStatus.providerUnavailable,
      provider: AuthProvider.firebase,
      statusDetail: 'Firebase Auth is not configured for this build.',
    );

    await _pumpMe(tester, aiRepository, authState: unavailableState);
    await _scrollUntilVisible(tester, find.text('Provider unavailable'));

    expect(find.text('Firebase Auth'), findsOneWidget);
    expect(find.textContaining('not configured'), findsWidgets);
    expect(find.text('Use mock account'), findsOneWidget);
  });

  testWidgets('user can select provider and model', (tester) async {
    final repository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, repository);
    await _openProviderMenu(tester);
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();

    expect(find.text('gpt-4.1-mini'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-4.1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save AI settings'));
    await tester.pumpAndSettle();

    final settings = await repository.loadSettings();

    expect(settings.provider, AiProvider.openai);
    expect(settings.model, 'gpt-4.1');
    expect(find.text('OpenAI gpt-4.1 saved.'), findsOneWidget);
  });

  testWidgets('user can save, update, and delete token state', (tester) async {
    final repository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, repository);
    await _scrollUntilVisible(tester, find.text('Save token'));
    await tester.enterText(
      find.byKey(const Key('ai-provider-token-field')),
      ' entered provider value ',
    );
    await tester.tap(find.text('Save token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isTrue);
    expect(find.text('Token saved'), findsOneWidget);
    expect(find.text('entered provider value'), findsNothing);
    expect(find.text('Token saved locally.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ai-provider-token-field')),
      'updated provider value',
    );
    await _scrollUntilVisible(tester, find.text('Update token'));
    await tester.tap(find.text('Update token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isTrue);
    expect(find.text('updated provider value'), findsNothing);

    await _scrollUntilVisible(tester, find.text('Delete token'));
    await tester.tap(find.text('Delete token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isFalse);
    expect(find.text('No token saved'), findsOneWidget);
    expect(find.text('Token deleted from this device.'), findsOneWidget);
  });

  testWidgets('user can save, update, and delete FoodData Central key state', (
    tester,
  ) async {
    final repository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, repository);
    await _scrollUntilVisible(tester, find.text('Save FoodData Central key'));
    await tester.enterText(
      find.byKey(const Key('fooddata-central-api-key-field')),
      ' entered nutrition value ',
    );
    await tester.tap(find.text('Save FoodData Central key'));
    await tester.pumpAndSettle();

    expect((await repository.loadFoodDataCentralKeyState()).hasKey, isTrue);
    expect(find.text('FoodData Central key saved'), findsOneWidget);
    expect(find.text('entered nutrition value'), findsNothing);
    expect(find.text('FoodData Central key saved locally.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fooddata-central-api-key-field')),
      'updated nutrition value',
    );
    await _scrollUntilVisible(tester, find.text('Update FoodData Central key'));
    await tester.tap(find.text('Update FoodData Central key'));
    await tester.pumpAndSettle();

    expect((await repository.loadFoodDataCentralKeyState()).hasKey, isTrue);
    expect(find.text('updated nutrition value'), findsNothing);

    await _scrollUntilVisible(tester, find.text('Delete FoodData Central key'));
    await tester.tap(find.text('Delete FoodData Central key'));
    await tester.pumpAndSettle();

    expect((await repository.loadFoodDataCentralKeyState()).hasKey, isFalse);
    expect(find.text('No FoodData Central key'), findsOneWidget);
    expect(
      find.text('FoodData Central key deleted from this device.'),
      findsOneWidget,
    );
  });

  testWidgets('health connection starts disconnected until user intent', (
    tester,
  ) async {
    final aiRepository = InMemoryAiSettingsRepository();

    await _pumpMe(tester, aiRepository);
    await _scrollUntilVisible(tester, find.text('Health connection'));

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.textContaining('until you choose Connect'), findsOneWidget);
    expect(find.text('Connect health'), findsOneWidget);
  });

  testWidgets('user can connect and disconnect mock health signals', (
    tester,
  ) async {
    final aiRepository = InMemoryAiSettingsRepository();
    final healthRepository = InMemoryHealthRepository();

    await _pumpMe(tester, aiRepository, healthRepository: healthRepository);
    await _scrollUntilVisible(tester, find.text('Connect health'));
    await tester.tap(find.text('Connect health'));
    await tester.pumpAndSettle();

    expect(
      (await healthRepository.loadState()).status,
      HealthConnectionStatus.connected,
    );
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('6.8h sleep'), findsOneWidget);
    expect(find.text('Disconnect health'), findsOneWidget);

    await tester.tap(find.text('Disconnect health'));
    await tester.pumpAndSettle();

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Health connection disconnected.'), findsOneWidget);
  });

  testWidgets('health denied and unavailable states are visible', (
    tester,
  ) async {
    final aiRepository = InMemoryAiSettingsRepository();
    final deniedState = const HealthConnectionState(
      status: HealthConnectionStatus.denied,
      supportedTypes: HealthConnectionState.mvpTypes,
      enabledTypes: {},
      statusDetail: 'Permission was previously denied.',
    );

    await _pumpMe(tester, aiRepository, healthState: deniedState);
    await _scrollUntilVisible(tester, find.text('Permission denied'));

    expect(find.textContaining('change permission'), findsOneWidget);

    final unavailableState = const HealthConnectionState(
      status: HealthConnectionStatus.unavailable,
      supportedTypes: {},
      enabledTypes: {},
      statusDetail: 'No HealthKit or Health Connect bridge is configured.',
    );

    await _pumpMe(tester, aiRepository, healthState: unavailableState);
    await _scrollUntilVisible(tester, find.text('Unavailable'));

    expect(find.textContaining('not available in this build'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connect health'),
    );
    expect(button.onPressed, isNull);
  });
}
