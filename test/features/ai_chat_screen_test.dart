import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/models/ai_chat.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/nutrition.dart';
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

class _ProviderFailureChatAdapter implements AiChatAdapter {
  const _ProviderFailureChatAdapter(this.kind);

  final AiProviderFailureKind kind;

  @override
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  }) {
    throw AiProviderException(kind, 'simulated provider failure');
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

const _openAiMissingTokenConfiguration = AiAdapterConfiguration(
  settings: AiProviderSettings(
    provider: AiProvider.openai,
    model: 'gpt-4.1-mini',
  ),
  tokenState: AiTokenState(
    hasToken: false,
    isSecureStorage: true,
    storageLabel: 'test secure storage',
  ),
);

void main() {
  final testNow = DateTime(2026, 6, 29, 15, 30);

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
          now: testNow,
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

  testWidgets('production default chat context uses current day', (
    tester,
  ) async {
    final runtimeNow = DateTime.now();
    final repository = InMemoryNutritionRepository(
      seedMeals: [
        Meal(
          id: 'runtime-chat-meal',
          name: 'Runtime chat breakfast',
          eatenAt: runtimeNow,
          source: NutritionSeedData.userSource,
          items: const [
            MealItem(
              id: 'runtime-chat-oats',
              food: FoodItem(
                id: 'runtime-chat-oats-food',
                name: 'Runtime chat oats',
                servingDescription: '1 bowl',
                nutritionPerServing: MacroTotals(
                  calories: 350,
                  proteinGrams: 24,
                  carbsGrams: 45,
                  fatGrams: 8,
                ),
                source: NutritionSeedData.userSource,
              ),
              servings: 1,
              source: NutritionSeedData.userSource,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        AiChatScreen(
          profile: _profile(),
          nutritionRepository: repository,
          chatRepository: InMemoryAiChatRepository(),
          configuration: _configuration,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Meals logged: Runtime chat breakfast'),
      findsOneWidget,
    );
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
          now: testNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What should I eat next?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text(
        'Companion response unavailable. Try again, check provider settings, or keep planning manually.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders provider rate limit with recovery options', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AiChatScreen(
          profile: _profile(),
          nutritionRepository: InMemoryNutritionRepository(),
          chatRepository: InMemoryAiChatRepository(),
          configuration: _configuration,
          adapter: const _ProviderFailureChatAdapter(
            AiProviderFailureKind.rateLimited,
          ),
          now: testNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What should I eat next?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text(
        'Provider rate limit reached. Try again later or keep planning manually.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders real provider missing-token recovery options', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AiChatScreen(
          profile: _profile(),
          nutritionRepository: InMemoryNutritionRepository(),
          chatRepository: InMemoryAiChatRepository(),
          configuration: _openAiMissingTokenConfiguration,
          adapter: RealProviderAiChatAdapter(
            configuration: _openAiMissingTokenConfiguration,
            readToken: () async => null,
          ),
          now: testNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What should I eat next?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(
      find.text(
        'Provider token missing. Add a token in Me or keep planning manually.',
      ),
      findsOneWidget,
    );
  });
}
