import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:ai_nutrition_companion/domain/repositories/onboarding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OnboardingProfile _profile() {
  return OnboardingProfile(
    primaryGoal: 'Build muscle',
    proteinGoalGrams: 132,
    targetWeightKg: 78,
    dietaryPreferences: const ['high protein', 'low prep'],
    allergies: const ['peanuts'],
    dislikedFoods: const ['raw onion'],
    coachingTone: 'direct and brief',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29, 12),
  );
}

void main() {
  test('onboarding profile maps to nutrition preferences and goals', () {
    final profile = _profile();

    final preferences = profile.toUserPreferences();
    final goal = profile.toNutritionGoal();

    expect(preferences.primaryGoal, 'Build muscle');
    expect(preferences.dietaryPreferences, ['high protein', 'low prep']);
    expect(preferences.allergies, ['peanuts']);
    expect(preferences.dislikedFoods, ['raw onion']);
    expect(preferences.coachingTone, 'direct and brief');
    expect(goal.proteinGrams, 132);
  });

  test(
    'shared preferences repository saves, loads, and clears profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = await SharedPreferencesOnboardingRepository.create();

      expect(await repository.loadProfile(), isNull);

      await repository.saveProfile(_profile());
      final loaded = await repository.loadProfile();

      expect(loaded?.primaryGoal, 'Build muscle');
      expect(loaded?.proteinGoalGrams, 132);
      expect(loaded?.targetWeightKg, 78);
      expect(loaded?.hasRequiredConsent, isTrue);

      await repository.clearProfile();

      expect(await repository.loadProfile(), isNull);
    },
  );

  test(
    'stored profile without required consent is treated as first run',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = await SharedPreferencesOnboardingRepository.create();

      await repository.saveProfile(
        OnboardingProfile(
          primaryGoal: 'Build muscle',
          proteinGoalGrams: 120,
          coachingTone: 'calm and practical',
          acceptedNutritionDisclaimer: true,
          acceptedAiGuidanceDisclaimer: false,
          acceptedPrivacyBoundary: true,
          completedAt: DateTime(2026, 6, 29),
        ),
      );

      expect(await repository.loadProfile(), isNull);
    },
  );
}
