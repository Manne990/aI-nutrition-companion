import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
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
  InMemoryAiSettingsRepository repository,
) async {
  await tester.pumpWidget(
    _wrap(
      MeScreen(
        profile: _profile(),
        aiSettingsRepository: repository,
        onAiSettingsChanged: () async {},
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
    expect(find.text('Secure local storage'), findsOneWidget);
    expect(
      find.textContaining('Mock AI is the default for tests and local CI'),
      findsOneWidget,
    );
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
    await tester.enterText(find.byType(TextField), ' sk-test-token ');
    await tester.tap(find.text('Save token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isTrue);
    expect(find.text('Token saved'), findsOneWidget);
    expect(find.text('sk-test-token'), findsNothing);
    expect(find.text('Token saved locally.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sk-updated-token');
    await _scrollUntilVisible(tester, find.text('Update token'));
    await tester.tap(find.text('Update token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isTrue);
    expect(find.text('sk-updated-token'), findsNothing);

    await _scrollUntilVisible(tester, find.text('Delete token'));
    await tester.tap(find.text('Delete token'));
    await tester.pumpAndSettle();

    expect((await repository.loadTokenState()).hasToken, isFalse);
    expect(find.text('No token saved'), findsOneWidget);
    expect(find.text('Token deleted from this device.'), findsOneWidget);
  });
}
