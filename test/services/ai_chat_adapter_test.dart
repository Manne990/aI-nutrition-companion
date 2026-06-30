import 'dart:async';
import 'dart:io';

import 'package:ai_nutrition_companion/domain/models/ai_chat.dart';
import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/meal_suggestion.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/services/adapters/ai_chat_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAiProviderTransport implements AiProviderTransport {
  _RecordingAiProviderTransport({
    required this.statusCode,
    required this.body,
    this.failure,
  });

  final int statusCode;
  final String body;
  final Object? failure;
  Uri? uri;
  Map<String, String>? headers;
  String? requestBody;

  @override
  Future<AiProviderTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    this.uri = uri;
    this.headers = headers;
    requestBody = body;
    return AiProviderTransportResponse(statusCode: statusCode, body: this.body);
  }
}

void main() {
  const configuration = AiAdapterConfiguration(
    settings: AiProviderSettings.defaults,
    tokenState: AiTokenState(
      hasToken: false,
      isSecureStorage: true,
      storageLabel: 'test secure storage',
    ),
  );
  const suggestion = MealSuggestion(
    title: 'Skyr bowl with berries',
    summary: 'Quick protein with fruit.',
    proteinGrams: 32,
    calories: 410,
    prepMinutes: 6,
    ingredientAvailability: 'All ingredients available',
    nutritionRationale: 'Closes most of today protein gap',
    source: NutritionSource.aiEstimated,
    imageAssetKey: 'fixture-skyr-bowl',
  );

  AiChatContext context() {
    final repository = InMemoryNutritionRepository();
    return AiChatContext(
      preferences: repository.userPreferences(),
      summary: repository.dailySummary(DateTime(2026, 6, 29, 15, 30)),
      configuration: configuration,
      currentSuggestion: suggestion,
    );
  }

  test('builds deterministic context summary from user and day state', () {
    final summary = buildAiChatContextSummary(context());

    expect(summary, contains('Build steady high-protein habits'));
    expect(summary, contains('2 meals today: Skyr bowl, Chicken salad'));
    expect(summary, contains('45g protein remaining'));
    expect(summary, contains('current suggestion: Skyr bowl with berries'));
    expect(summary, contains('adapter: OpenAI gpt-4.1-mini'));
  });

  test('routes safety boundaries before ordinary advice', () {
    expect(
      routeAiChatSafetyBoundary('Can you diagnose diabetes from this meal?'),
      AiChatSafetyBoundary.medical,
    );
    expect(
      routeAiChatSafetyBoundary('Help me stop eating and lose weight fast'),
      AiChatSafetyBoundary.eatingDisorder,
    );
    expect(
      routeAiChatSafetyBoundary('Guarantee exact calories for this photo'),
      AiChatSafetyBoundary.uncertainty,
    );
  });

  test('returns contextual protein and next-meal responses', () async {
    const adapter = MockAiChatAdapter();

    final protein = await adapter.sendMessage(
      prompt: 'How can I hit my protein goal today?',
      context: context(),
      history: const [],
    );
    final nextMeal = await adapter.sendMessage(
      prompt: 'What should I eat next?',
      context: context(),
      history: const [],
    );

    expect(protein.message, contains('45g protein left'));
    expect(protein.message, contains('Skyr bowl with berries'));
    expect(nextMeal.message, contains('Skyr bowl with berries'));
    expect(nextMeal.message, contains('32g protein'));
  });

  test('medical prompt produces safe boundary response', () async {
    const adapter = MockAiChatAdapter();

    final response = await adapter.sendMessage(
      prompt: 'Can this treat my symptoms?',
      context: context(),
      history: const [],
    );

    expect(response.safetyBoundary, AiChatSafetyBoundary.medical);
    expect(response.message, contains('cannot diagnose, treat'));
  });

  test(
    'real OpenAI adapter sends user token through injected transport',
    () async {
      final transport = _RecordingAiProviderTransport(
        statusCode: 200,
        body: '{"choices":[{"message":{"content":"Choose the skyr bowl."}}]}',
      );
      final adapter = RealProviderAiChatAdapter(
        configuration: const AiAdapterConfiguration(
          settings: AiProviderSettings(
            provider: AiProvider.openai,
            model: 'gpt-4.1-mini',
          ),
          tokenState: AiTokenState(
            hasToken: true,
            isSecureStorage: true,
            storageLabel: 'test secure storage',
          ),
        ),
        readToken: () async => 'user-owned-token',
        transport: transport,
      );

      final response = await adapter.sendMessage(
        prompt: 'What should I eat next?',
        context: context(),
        history: const [],
      );

      expect(response.message, 'Choose the skyr bowl.');
      expect(
        transport.uri,
        Uri.https('api.openai.com', '/v1/chat/completions'),
      );
      expect(transport.headers?['authorization'], 'Bearer user-owned-token');
      expect(transport.requestBody, contains('"model":"gpt-4.1-mini"'));
      expect(transport.requestBody, isNot(contains('user-owned-token')));
    },
  );

  test(
    'real Gemini adapter sends user token through injected transport',
    () async {
      final transport = _RecordingAiProviderTransport(
        statusCode: 200,
        body:
            '{"candidates":[{"content":{"parts":[{"text":"Try oats with yogurt."}]}}]}',
      );
      final adapter = RealProviderAiChatAdapter(
        configuration: const AiAdapterConfiguration(
          settings: AiProviderSettings(
            provider: AiProvider.gemini,
            model: 'gemini-1.5-flash-latest',
          ),
          tokenState: AiTokenState(
            hasToken: true,
            isSecureStorage: true,
            storageLabel: 'test secure storage',
          ),
        ),
        readToken: () async => 'gemini-user-token',
        transport: transport,
      );

      final response = await adapter.sendMessage(
        prompt: 'What should I eat next?',
        context: context(),
        history: const [],
      );

      expect(response.message, 'Try oats with yogurt.');
      expect(
        transport.uri,
        Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/gemini-1.5-flash-latest:generateContent',
          {'key': 'gemini-user-token'},
        ),
      );
      expect(transport.requestBody, contains('systemInstruction'));
      expect(transport.requestBody, isNot(contains('gemini-user-token')));
    },
  );

  test(
    'real Anthropic adapter sends user token through injected transport',
    () async {
      final transport = _RecordingAiProviderTransport(
        statusCode: 200,
        body: '{"content":[{"type":"text","text":"Add eggs on toast."}]}',
      );
      final adapter = RealProviderAiChatAdapter(
        configuration: const AiAdapterConfiguration(
          settings: AiProviderSettings(
            provider: AiProvider.anthropic,
            model: 'claude-3-5-haiku-latest',
          ),
          tokenState: AiTokenState(
            hasToken: true,
            isSecureStorage: true,
            storageLabel: 'test secure storage',
          ),
        ),
        readToken: () async => 'anthropic-user-token',
        transport: transport,
      );

      final response = await adapter.sendMessage(
        prompt: 'What should I eat next?',
        context: context(),
        history: const [],
      );

      expect(response.message, 'Add eggs on toast.');
      expect(transport.uri, Uri.https('api.anthropic.com', '/v1/messages'));
      expect(transport.headers?['x-api-key'], 'anthropic-user-token');
      expect(transport.headers?['anthropic-version'], '2023-06-01');
      expect(transport.requestBody, isNot(contains('anthropic-user-token')));
    },
  );

  test('real adapter reports missing token without network call', () async {
    final transport = _RecordingAiProviderTransport(
      statusCode: 200,
      body: '{"choices":[]}',
    );
    final adapter = RealProviderAiChatAdapter(
      configuration: const AiAdapterConfiguration(
        settings: AiProviderSettings(
          provider: AiProvider.openai,
          model: 'gpt-4.1-mini',
        ),
        tokenState: AiTokenState(
          hasToken: false,
          isSecureStorage: true,
          storageLabel: 'test secure storage',
        ),
      ),
      readToken: () async => null,
      transport: transport,
    );

    await expectLater(
      adapter.sendMessage(
        prompt: 'What should I eat next?',
        context: context(),
        history: const [],
      ),
      throwsA(
        isA<AiProviderException>().having(
          (error) => error.kind,
          'kind',
          AiProviderFailureKind.missingCredential,
        ),
      ),
    );
    expect(transport.uri, isNull);
  });

  test('real adapter maps provider failures into recoverable kinds', () async {
    Future<AiProviderFailureKind> failureKindFor(
      int statusCode, {
      String body = '{}',
    }) async {
      final adapter = RealProviderAiChatAdapter(
        configuration: const AiAdapterConfiguration(
          settings: AiProviderSettings(
            provider: AiProvider.openai,
            model: 'gpt-4.1-mini',
          ),
          tokenState: AiTokenState(
            hasToken: true,
            isSecureStorage: true,
            storageLabel: 'test secure storage',
          ),
        ),
        readToken: () async => 'user-token',
        transport: _RecordingAiProviderTransport(
          statusCode: statusCode,
          body: body,
        ),
      );
      try {
        await adapter.sendMessage(
          prompt: 'What should I eat next?',
          context: context(),
          history: const [],
        );
      } on AiProviderException catch (error) {
        return error.kind;
      }
      fail('Expected provider exception');
    }

    expect(await failureKindFor(401), AiProviderFailureKind.missingCredential);
    expect(await failureKindFor(429), AiProviderFailureKind.rateLimited);
    expect(await failureKindFor(504), AiProviderFailureKind.timeout);
    expect(
      await failureKindFor(503),
      AiProviderFailureKind.providerUnavailable,
    );
    expect(await failureKindFor(400), AiProviderFailureKind.providerError);
    expect(
      await failureKindFor(200, body: '{"choices":[]}'),
      AiProviderFailureKind.malformedResponse,
    );
  });

  test('real adapter maps transport failures into recoverable kinds', () async {
    Future<AiProviderFailureKind> failureKindFor(Object failure) async {
      final adapter = RealProviderAiChatAdapter(
        configuration: const AiAdapterConfiguration(
          settings: AiProviderSettings(
            provider: AiProvider.openai,
            model: 'gpt-4.1-mini',
          ),
          tokenState: AiTokenState(
            hasToken: true,
            isSecureStorage: true,
            storageLabel: 'test secure storage',
          ),
        ),
        readToken: () async => 'user-token',
        transport: _RecordingAiProviderTransport(
          statusCode: 200,
          body: '{}',
          failure: failure,
        ),
      );
      try {
        await adapter.sendMessage(
          prompt: 'What should I eat next?',
          context: context(),
          history: const [],
        );
      } on AiProviderException catch (error) {
        return error.kind;
      }
      fail('Expected provider exception');
    }

    expect(
      await failureKindFor(TimeoutException('simulated timeout')),
      AiProviderFailureKind.timeout,
    );
    expect(
      await failureKindFor(const SocketException('simulated offline')),
      AiProviderFailureKind.providerUnavailable,
    );
  });
}
