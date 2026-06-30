import 'ai_settings.dart';
import 'auth.dart';
import 'health.dart';
import 'onboarding.dart';

class AppDiagnosticsConfig {
  const AppDiagnosticsConfig({
    this.appName = 'AI Nutrition Companion',
    this.versionName = '1.0.0',
    this.buildNumber = '1',
  });

  final String appName;
  final String versionName;
  final String buildNumber;

  String get versionLabel => '$versionName (build $buildNumber)';
}

class AppDiagnosticsSnapshot {
  const AppDiagnosticsSnapshot({
    required this.config,
    required this.profile,
    required this.aiSettings,
    required this.aiTokenState,
    required this.authState,
    required this.healthState,
  });

  final AppDiagnosticsConfig config;
  final OnboardingProfile profile;
  final AiProviderSettings aiSettings;
  final AiTokenState aiTokenState;
  final AuthAccountState authState;
  final HealthConnectionState healthState;

  String exportText({List<String> sensitiveValues = const []}) {
    final aiConfiguration = AiAdapterConfiguration(
      settings: aiSettings,
      tokenState: aiTokenState,
    );
    final enabledHealthTypes = healthState.enabledTypes
        .map((type) => type.label)
        .join(', ');

    final lines = [
      '${config.appName} diagnostics',
      'App version: ${config.versionLabel}',
      'Privacy: copied manually by the user; raw provider tokens are not included.',
      '',
      'AI provider',
      '- Provider: ${aiSettings.option.label}',
      '- Model: ${aiSettings.model}',
      '- Mode: ${aiConfiguration.modeLabel}',
      '- AI token: ${_secretState(aiTokenState.hasToken)}',
      '- AI token storage: ${aiTokenState.storageLabel}',
      '- AI token storage available: ${_yesNo(aiTokenState.isAvailable)}',
      '',
      'Account',
      '- Status: ${authState.statusLabel}',
      '- Provider: ${authState.provider.label}',
      '- User label: ${authState.userLabel ?? 'not signed in'}',
      '',
      'Health',
      '- Status: ${healthState.statusLabel}',
      '- Provider: ${healthState.providerLabel}',
      '- Enabled data types: ${enabledHealthTypes.isEmpty ? 'none' : enabledHealthTypes}',
      '',
      'Local data',
      '- Backup preference: ${profile.backupPreference.label}',
      '',
      'Feature state',
      '- Onboarding complete: yes',
      '- Nutrition disclaimer accepted: ${_yesNo(profile.acceptedNutritionDisclaimer)}',
      '- AI guidance disclaimer accepted: ${_yesNo(profile.acceptedAiGuidanceDisclaimer)}',
      '- Privacy boundary accepted: ${_yesNo(profile.acceptedPrivacyBoundary)}',
      '- Dietary preference count: ${profile.dietaryPreferences.length}',
      '- Protein goal configured: ${_yesNo(profile.proteinGoalGrams > 0)}',
    ];

    return _redactSensitiveValues(lines.join('\n'), sensitiveValues);
  }
}

String _yesNo(bool value) => value ? 'yes' : 'no';

String _secretState(bool hasSecret) {
  return hasSecret ? 'saved (redacted)' : 'not saved';
}

String _redactSensitiveValues(String text, List<String> sensitiveValues) {
  var redacted = text;
  for (final value in sensitiveValues) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    redacted = redacted.replaceAll(trimmed, '[redacted]');
  }
  return redacted;
}
