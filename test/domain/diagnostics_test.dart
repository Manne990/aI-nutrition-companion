import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/models/auth.dart';
import 'package:ai_nutrition_companion/domain/models/diagnostics.dart';
import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/domain/models/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

OnboardingProfile _profile() {
  return OnboardingProfile(
    primaryGoal: 'Build steady high-protein habits',
    proteinGoalGrams: 110,
    dietaryPreferences: const ['high protein', 'vegetarian'],
    coachingTone: 'calm and practical',
    acceptedNutritionDisclaimer: true,
    acceptedAiGuidanceDisclaimer: true,
    acceptedPrivacyBoundary: true,
    completedAt: DateTime(2026, 6, 29),
  );
}

void main() {
  test('diagnostics export reports app and provider state without secrets', () {
    final snapshot = AppDiagnosticsSnapshot(
      config: const AppDiagnosticsConfig(
        versionName: '9.8.7',
        buildNumber: '42',
      ),
      profile: _profile(),
      aiSettings: const AiProviderSettings(
        provider: AiProvider.openai,
        model: 'gpt-4.1-mini',
      ),
      aiTokenState: const AiTokenState(
        hasToken: true,
        isSecureStorage: true,
        storageLabel: 'test secure token storage sk-live-secret',
      ),
      authState: const AuthAccountState(
        status: AuthConnectionStatus.providerUnavailable,
        provider: AuthProvider.supabase,
      ),
      healthState: const HealthConnectionState(
        status: HealthConnectionStatus.connected,
        supportedTypes: HealthConnectionState.mvpTypes,
        enabledTypes: {HealthDataType.activity, HealthDataType.sleep},
      ),
    );

    final export = snapshot.exportText(
      sensitiveValues: const ['sk-live-secret'],
    );

    expect(export, contains('App version: 9.8.7 (build 42)'));
    expect(export, contains('- Provider: OpenAI'));
    expect(export, contains('- Mode: OpenAI ready'));
    expect(export, contains('- AI token: saved (redacted)'));
    expect(export, contains('- Provider: Supabase Auth'));
    expect(export, contains('- Enabled data types: Activity, Sleep'));
    expect(export, contains('- Dietary preference count: 2'));
    expect(export, contains('test secure token storage [redacted]'));
    expect(export, isNot(contains('sk-live-secret')));
    expect(export, isNot(contains('FoodData Central key')));
  });
}
