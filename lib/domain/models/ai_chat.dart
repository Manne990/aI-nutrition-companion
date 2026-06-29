import 'nutrition.dart';
import 'meal_suggestion.dart';
import 'ai_settings.dart';

enum AiChatRole { user, assistant }

enum AiChatSafetyBoundary { none, medical, eatingDisorder, uncertainty }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.safetyBoundary = AiChatSafetyBoundary.none,
  });

  final String id;
  final AiChatRole role;
  final String content;
  final DateTime createdAt;
  final AiChatSafetyBoundary safetyBoundary;

  bool get isUser => role == AiChatRole.user;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'safetyBoundary': safetyBoundary.name,
    };
  }

  factory AiChatMessage.fromJson(Map<String, Object?> json) {
    return AiChatMessage(
      id: json['id'] as String? ?? 'message-missing-id',
      role: AiChatRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => AiChatRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      safetyBoundary: AiChatSafetyBoundary.values.firstWhere(
        (boundary) => boundary.name == json['safetyBoundary'],
        orElse: () => AiChatSafetyBoundary.none,
      ),
    );
  }
}

class AiChatContext {
  const AiChatContext({
    required this.preferences,
    required this.summary,
    required this.configuration,
    this.currentSuggestion,
  });

  final UserPreferences preferences;
  final DailySummary summary;
  final AiAdapterConfiguration configuration;
  final MealSuggestion? currentSuggestion;

  double get proteinRemainingGrams => summary.proteinRemainingGrams ?? 0;

  String get mealsSummary {
    if (summary.meals.isEmpty) {
      return 'no meals logged today';
    }
    return summary.meals.map((meal) => meal.name).join(', ');
  }

  String get preferenceSummary {
    final preferencesList = preferences.dietaryPreferences;
    if (preferencesList.isEmpty) {
      return preferences.primaryGoal;
    }
    return '${preferences.primaryGoal}; ${preferencesList.join(', ')}';
  }

  String get providerSummary {
    return '${configuration.providerLabel} ${configuration.settings.model}';
  }
}

class AiChatResponse {
  const AiChatResponse({
    required this.message,
    this.safetyBoundary = AiChatSafetyBoundary.none,
  });

  final String message;
  final AiChatSafetyBoundary safetyBoundary;
}
