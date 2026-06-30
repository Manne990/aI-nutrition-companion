import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/models/ai_chat.dart';
import '../../domain/models/ai_settings.dart';

abstract interface class AiChatAdapter {
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  });
}

typedef AiProviderTokenReader = Future<String?> Function();

abstract interface class AiProviderTransport {
  Future<AiProviderTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  });
}

class AiProviderTransportResponse {
  const AiProviderTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class HttpAiProviderTransport implements AiProviderTransport {
  const HttpAiProviderTransport({this.timeout = const Duration(seconds: 30)});

  final Duration timeout;

  @override
  Future<AiProviderTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      return AiProviderTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class RealProviderAiChatAdapter implements AiChatAdapter {
  const RealProviderAiChatAdapter({
    required this.configuration,
    required this.readToken,
    this.transport = const HttpAiProviderTransport(),
  });

  final AiAdapterConfiguration configuration;
  final AiProviderTokenReader readToken;
  final AiProviderTransport transport;

  @override
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  }) async {
    if (configuration.settings.usesMockProvider) {
      return const MockAiChatAdapter().sendMessage(
        prompt: prompt,
        context: context,
        history: history,
      );
    }

    if (!configuration.tokenState.isAvailable) {
      throw AiProviderException(
        AiProviderFailureKind.missingCredential,
        'Provider token storage is unavailable.',
      );
    }

    final token = await _readToken();
    if (token == null || token.trim().isEmpty) {
      throw AiProviderException(
        AiProviderFailureKind.missingCredential,
        'Provider token is missing.',
      );
    }

    final settings = configuration.settings.normalized();
    final boundary = routeAiChatSafetyBoundary(prompt);
    if (boundary != AiChatSafetyBoundary.none) {
      return AiChatResponse(
        safetyBoundary: boundary,
        message: _safetyResponse(boundary, context),
      );
    }

    return switch (settings.provider) {
      AiProvider.openai => _sendOpenAi(
        token: token.trim(),
        prompt: prompt,
        context: context,
        history: history,
        model: settings.model,
      ),
      AiProvider.anthropic => _sendAnthropic(
        token: token.trim(),
        prompt: prompt,
        context: context,
        history: history,
        model: settings.model,
      ),
      AiProvider.mock => const MockAiChatAdapter().sendMessage(
        prompt: prompt,
        context: context,
        history: history,
      ),
    };
  }

  Future<String?> _readToken() async {
    try {
      return await readToken();
    } catch (_) {
      throw AiProviderException(
        AiProviderFailureKind.providerUnavailable,
        'Provider token storage could not be read.',
      );
    }
  }

  Future<AiChatResponse> _sendOpenAi({
    required String token,
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
    required String model,
  }) async {
    final requestBody = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt(context)},
        for (final message in _requestHistory(prompt, history))
          {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          },
        {'role': 'user', 'content': prompt.trim()},
      ],
      'temperature': 0.3,
    });

    final response = await _postProvider(
      uri: Uri.https('api.openai.com', '/v1/chat/completions'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: requestBody,
    );
    final body = _decodeResponseMap(response.body);
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiProviderException(
        AiProviderFailureKind.malformedResponse,
        'OpenAI response did not include choices.',
      );
    }
    final first = _asObjectMap(choices.first);
    final message = _asObjectMap(first?['message']);
    final content = message?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw AiProviderException(
        AiProviderFailureKind.malformedResponse,
        'OpenAI response did not include message content.',
      );
    }
    return AiChatResponse(message: content.trim());
  }

  Future<AiChatResponse> _sendAnthropic({
    required String token,
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
    required String model,
  }) async {
    final messages = [
      for (final message in _requestHistory(prompt, history))
        {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.content,
        },
      {'role': 'user', 'content': prompt.trim()},
    ];
    final requestBody = jsonEncode({
      'model': model,
      'max_tokens': 500,
      'system': _systemPrompt(context),
      'messages': messages,
    });

    final response = await _postProvider(
      uri: Uri.https('api.anthropic.com', '/v1/messages'),
      headers: {
        'x-api-key': token,
        'anthropic-version': '2023-06-01',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: requestBody,
    );
    final body = _decodeResponseMap(response.body);
    final content = body['content'];
    if (content is! List || content.isEmpty) {
      throw AiProviderException(
        AiProviderFailureKind.malformedResponse,
        'Anthropic response did not include content.',
      );
    }
    final textParts = content
        .map(_asObjectMap)
        .nonNulls
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'])
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (textParts.isEmpty) {
      throw AiProviderException(
        AiProviderFailureKind.malformedResponse,
        'Anthropic response did not include text content.',
      );
    }
    return AiChatResponse(message: textParts.join('\n\n'));
  }

  Future<AiProviderTransportResponse> _postProvider({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await transport.post(
        uri: uri,
        headers: headers,
        body: body,
      );
      _throwForStatus(response.statusCode);
      return response;
    } on TimeoutException {
      throw AiProviderException(
        AiProviderFailureKind.timeout,
        'Provider request timed out.',
      );
    } on SocketException {
      throw AiProviderException(
        AiProviderFailureKind.providerUnavailable,
        'Provider network is unavailable.',
      );
    } on AiProviderException {
      rethrow;
    } catch (_) {
      throw AiProviderException(
        AiProviderFailureKind.providerUnavailable,
        'Provider request failed.',
      );
    }
  }

  void _throwForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    if (statusCode == 401 || statusCode == 403) {
      throw AiProviderException(
        AiProviderFailureKind.missingCredential,
        'Provider rejected the token.',
      );
    }
    if (statusCode == 408 || statusCode == 504) {
      throw AiProviderException(
        AiProviderFailureKind.timeout,
        'Provider request timed out.',
      );
    }
    if (statusCode == 429) {
      throw AiProviderException(
        AiProviderFailureKind.rateLimited,
        'Provider rate limit was reached.',
      );
    }
    if (statusCode >= 500) {
      throw AiProviderException(
        AiProviderFailureKind.providerUnavailable,
        'Provider service is unavailable.',
      );
    }
    throw AiProviderException(
      AiProviderFailureKind.providerError,
      'Provider rejected the request.',
    );
  }
}

class MockAiChatAdapter implements AiChatAdapter {
  const MockAiChatAdapter();

  @override
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  }) async {
    final normalized = _normalize(prompt);
    final safetyBoundary = routeAiChatSafetyBoundary(normalized);
    if (safetyBoundary != AiChatSafetyBoundary.none) {
      return AiChatResponse(
        safetyBoundary: safetyBoundary,
        message: _safetyResponse(safetyBoundary, context),
      );
    }

    if (_containsAny(normalized, const ['protein', 'hit my goal', 'goal'])) {
      return AiChatResponse(message: _proteinResponse(context));
    }

    if (_containsAny(normalized, const ['eat next', 'what should i eat'])) {
      return AiChatResponse(message: _nextMealResponse(context));
    }

    if (_containsAny(normalized, const ['why', 'explain'])) {
      return AiChatResponse(message: _explanationResponse(context));
    }

    return AiChatResponse(message: _generalResponse(context, history));
  }
}

AiChatSafetyBoundary routeAiChatSafetyBoundary(String prompt) {
  final normalized = _normalize(prompt);
  if (_containsAny(normalized, const [
    'diagnose',
    'treat',
    'cure',
    'insulin',
    'medication',
    'diabetes',
    'blood sugar',
    'disease',
    'symptom',
  ])) {
    return AiChatSafetyBoundary.medical;
  }
  if (_containsAny(normalized, const [
    'stop eating',
    'starve',
    'purge',
    'binge',
    'anorexia',
    'bulimia',
    'lose weight fast',
    'under 800 calories',
  ])) {
    return AiChatSafetyBoundary.eatingDisorder;
  }
  if (_containsAny(normalized, const [
    'exact calories',
    'guarantee',
    'certain',
    'perfect macros',
  ])) {
    return AiChatSafetyBoundary.uncertainty;
  }
  return AiChatSafetyBoundary.none;
}

String buildAiChatContextSummary(AiChatContext context) {
  final goal = context.summary.goal;
  final calorieGoal = goal?.calories == null
      ? 'no calorie target'
      : '${goal!.calories!.round()} kcal target';
  final suggestion = context.currentSuggestion?.title ?? 'no active suggestion';
  return [
    context.preferenceSummary,
    '${context.summary.meals.length} meals today: ${context.mealsSummary}',
    '${context.proteinRemainingGrams.round()}g protein remaining',
    calorieGoal,
    'current suggestion: $suggestion',
    'adapter: ${context.providerSummary}',
  ].join(' | ');
}

String _proteinResponse(AiChatContext context) {
  final remaining = context.proteinRemainingGrams.round();
  final suggestion = context.currentSuggestion;
  if (remaining <= 0) {
    return 'Your protein target is covered today. Keep the next choice comfortable and familiar; ${suggestion?.title ?? 'a lighter snack'} is optional rather than urgent.';
  }
  return 'You have about ${remaining}g protein left. ${suggestion?.title ?? 'A high-protein snack'} fits your ${context.preferences.primaryGoal.toLowerCase()} goal, and today already includes ${context.mealsSummary}.';
}

String _nextMealResponse(AiChatContext context) {
  final suggestion = context.currentSuggestion;
  if (suggestion == null) {
    return 'I would keep the next meal simple and protein-led because today shows ${context.mealsSummary}. Log one meal first if you want a sharper recommendation.';
  }
  return '${suggestion.title} is the practical next choice: ${suggestion.summary} It adds ${suggestion.proteinGrams.round()}g protein while keeping the day aligned with ${context.preferences.primaryGoal.toLowerCase()}.';
}

String _explanationResponse(AiChatContext context) {
  final suggestion = context.currentSuggestion;
  if (suggestion == null) {
    return 'I am using your goal, preferences, and today meal history, but there is not enough context for a specific meal yet.';
  }
  return 'The reasoning is ${suggestion.nutritionRationale.toLowerCase()}, with ${suggestion.ingredientAvailability.toLowerCase()}. I am also considering ${context.summary.meals.length} logged meals today.';
}

String _generalResponse(AiChatContext context, List<AiChatMessage> history) {
  final followUp = history.where((message) => message.isUser).isEmpty
      ? 'For a first step,'
      : 'For this follow-up,';
  return '$followUp focus on one practical choice: ${context.currentSuggestion?.title ?? 'a familiar high-protein option'}. I am using ${context.providerSummary} in mock response mode with this context: ${buildAiChatContextSummary(context)}.';
}

String _safetyResponse(AiChatSafetyBoundary boundary, AiChatContext context) {
  return switch (boundary) {
    AiChatSafetyBoundary.medical =>
      'I can help compare general food options, but I cannot diagnose, treat, or adjust medication. For medical nutrition decisions, use this as a question list for a qualified clinician.',
    AiChatSafetyBoundary.eatingDisorder =>
      'I cannot help with restriction, purging, or unsafe weight-loss tactics. A steadier option is to choose regular meals and speak with a qualified professional if food feels hard to manage.',
    AiChatSafetyBoundary.uncertainty =>
      'I cannot guarantee exact calories or perfect macros from partial data. Today has ${context.summary.itemsWithMissingNutrition} items with uncertain nutrition, so treat this as guidance until you confirm portions.',
    AiChatSafetyBoundary.none => '',
  };
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool _containsAny(String value, List<String> needles) {
  return needles.any(value.contains);
}

String _systemPrompt(AiChatContext context) {
  return [
    'You are a practical nutrition companion for general wellness support.',
    'Do not diagnose, treat, or provide medical instructions.',
    'Be concise, honest about uncertainty, and ask the user to confirm portions when nutrition is uncertain.',
    'Current local context: ${buildAiChatContextSummary(context)}',
  ].join('\n');
}

Map<String, Object?> _decodeResponseMap(String body) {
  try {
    final decoded = jsonDecode(body);
    final mapped = _asObjectMap(decoded);
    if (mapped != null) {
      return mapped;
    }
  } on FormatException {
    // Converted below to the domain provider failure type.
  }
  throw AiProviderException(
    AiProviderFailureKind.malformedResponse,
    'Provider returned malformed JSON.',
  );
}

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<AiChatMessage> _requestHistory(
  String prompt,
  List<AiChatMessage> history,
) {
  final filtered = history
      .where((message) => message.content.trim().isNotEmpty)
      .toList(growable: false);
  if (filtered.isEmpty) {
    return const [];
  }
  final last = filtered.last;
  if (last.isUser && last.content.trim() == prompt.trim()) {
    return filtered.take(filtered.length - 1).toList(growable: false);
  }
  return filtered;
}
