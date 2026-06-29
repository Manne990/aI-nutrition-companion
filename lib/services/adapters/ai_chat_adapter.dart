import '../../domain/models/ai_chat.dart';

abstract interface class AiChatAdapter {
  Future<AiChatResponse> sendMessage({
    required String prompt,
    required AiChatContext context,
    required List<AiChatMessage> history,
  });
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
