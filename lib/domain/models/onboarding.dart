import 'nutrition.dart';

class OnboardingProfile {
  const OnboardingProfile({
    required this.primaryGoal,
    required this.proteinGoalGrams,
    required this.coachingTone,
    required this.acceptedNutritionDisclaimer,
    required this.acceptedAiGuidanceDisclaimer,
    required this.acceptedPrivacyBoundary,
    required this.completedAt,
    this.backupPreference = LocalDataBackupPreference.localOnly,
    this.healthConnectionApproved = false,
    this.targetWeightKg,
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.dislikedFoods = const [],
  });

  final String primaryGoal;
  final double proteinGoalGrams;
  final double? targetWeightKg;
  final List<String> dietaryPreferences;
  final List<String> allergies;
  final List<String> dislikedFoods;
  final String coachingTone;
  final bool acceptedNutritionDisclaimer;
  final bool acceptedAiGuidanceDisclaimer;
  final bool acceptedPrivacyBoundary;
  final DateTime completedAt;
  final LocalDataBackupPreference backupPreference;
  final bool healthConnectionApproved;

  bool get hasRequiredConsent {
    return acceptedNutritionDisclaimer &&
        acceptedAiGuidanceDisclaimer &&
        acceptedPrivacyBoundary;
  }

  UserPreferences toUserPreferences() {
    return UserPreferences(
      primaryGoal: primaryGoal,
      dietaryPreferences: dietaryPreferences,
      allergies: allergies,
      dislikedFoods: dislikedFoods,
      coachingTone: coachingTone,
    );
  }

  NutritionGoal toNutritionGoal({double? calories}) {
    return NutritionGoal(proteinGrams: proteinGoalGrams, calories: calories);
  }

  Map<String, Object?> toJson() {
    return {
      'primaryGoal': primaryGoal,
      'proteinGoalGrams': proteinGoalGrams,
      'targetWeightKg': targetWeightKg,
      'dietaryPreferences': dietaryPreferences,
      'allergies': allergies,
      'dislikedFoods': dislikedFoods,
      'coachingTone': coachingTone,
      'acceptedNutritionDisclaimer': acceptedNutritionDisclaimer,
      'acceptedAiGuidanceDisclaimer': acceptedAiGuidanceDisclaimer,
      'acceptedPrivacyBoundary': acceptedPrivacyBoundary,
      'completedAt': completedAt.toIso8601String(),
      'backupPreference': backupPreference.name,
      'healthConnectionApproved': healthConnectionApproved,
    };
  }

  static OnboardingProfile fromJson(Map<String, Object?> json) {
    return OnboardingProfile(
      primaryGoal: _string(
        json['primaryGoal'],
        fallback: 'Build healthy habits',
      ),
      proteinGoalGrams: _double(json['proteinGoalGrams'], fallback: 100),
      targetWeightKg: _nullableDouble(json['targetWeightKg']),
      dietaryPreferences: _stringList(json['dietaryPreferences']),
      allergies: _stringList(json['allergies']),
      dislikedFoods: _stringList(json['dislikedFoods']),
      coachingTone: _string(json['coachingTone'], fallback: 'calm'),
      acceptedNutritionDisclaimer: json['acceptedNutritionDisclaimer'] == true,
      acceptedAiGuidanceDisclaimer:
          json['acceptedAiGuidanceDisclaimer'] == true,
      acceptedPrivacyBoundary: json['acceptedPrivacyBoundary'] == true,
      completedAt:
          DateTime.tryParse(_string(json['completedAt'], fallback: '')) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      backupPreference: _backupPreference(json['backupPreference']),
      healthConnectionApproved: json['healthConnectionApproved'] == true,
    );
  }
}

LocalDataBackupPreference _backupPreference(Object? value) {
  if (value is String) {
    for (final preference in LocalDataBackupPreference.values) {
      if (preference.name == value) {
        return preference;
      }
    }
  }
  return LocalDataBackupPreference.localOnly;
}

String _string(Object? value, {required String fallback}) {
  return value is String && value.trim().isNotEmpty ? value : fallback;
}

double _double(Object? value, {required double fallback}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
