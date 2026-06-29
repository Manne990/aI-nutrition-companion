import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/ai_chat.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_chat_repository.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/features/chat/ai_chat_screen.dart';
import 'package:ai_nutrition_companion/services/adapters/ai_chat_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingChatAdapter implements AiChatAdapter {
  const _FailingChatAdapter();

  @override
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  }) {
    throw StateError('adapter unavailable');
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AppTheme.light(), home: child);
}

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

const _configuration = AiAdapterConfiguration(
  settings: AiProviderSettings.defaults,
  tokenState: AiTokenState(
    hasToken: false,
    isSecureStorage: true,
    storageLabel: 'test secure storage',
  ),
);

void main() {
  testWidgets('renders empty chat state with today context and entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AiChatScreen(
          profile: _profile(),
          nutritionRepository: InMemoryNutritionRepository(),
          chatRepository: InMemoryAiChatRepository(),
          configuration: _configuration,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask about today'), findsWidgets);
    expect(
      find.textContaining('Meals logged: Skyr bowl, Chicken salad'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('renders adapter error without dropping user prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AiChatScreen(
          profile: _profile(),
          nutritionRepository: InMemoryNutritionRepository(),
          chatRepository: InMemoryAiChatRepository(),
          configuration: _configuration,
          adapter: const _FailingChatAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What should I eat next?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text('Companion response unavailable. Try again.'),
      findsOneWidget,
    );
  });
}
