import 'package:ai_nutrition_companion/domain/models/ai_settings.dart';
import 'package:ai_nutrition_companion/domain/repositories/ai_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('provider settings normalize unknown or mismatched models', () {
    final settings = AiProviderSettings.fromJson({
      'provider': 'openai',
      'model': 'unknown-model',
    });

    expect(settings.provider, AiProvider.openai);
    expect(settings.model, 'gpt-4.1-mini');

    final switched = settings.copyWith(provider: AiProvider.anthropic);

    expect(switched.provider, AiProvider.anthropic);
    expect(switched.model, 'claude-3-5-haiku-latest');
  });

  test(
    'in-memory repository creates updates and deletes token state',
    () async {
      final repository = InMemoryAiSettingsRepository();
      final defaultSettings = await repository.loadSettings();

      expect(defaultSettings.provider, AiProvider.mock);
      expect(defaultSettings.model, 'mock-companion-v1');
      expect((await repository.loadTokenState()).hasToken, isFalse);

      await repository.saveSettings(
        const AiProviderSettings(provider: AiProvider.openai, model: 'gpt-4.1'),
      );
      await repository.saveToken(' entered provider value ');

      final configuration = await repository.loadAdapterConfiguration();

      expect(configuration.settings.provider, AiProvider.openai);
      expect(configuration.settings.model, 'gpt-4.1');
      expect(configuration.tokenState.hasToken, isTrue);
      expect(configuration.canUseRealProvider, isTrue);
      expect(configuration.shouldUseMock, isFalse);
      expect(await repository.readProviderToken(), 'entered provider value');

      await repository.saveToken('updated provider value');
      expect((await repository.loadTokenState()).hasToken, isTrue);

      await repository.deleteToken();
      expect((await repository.loadTokenState()).hasToken, isFalse);
    },
  );

  test(
    'shared preferences repository keeps settings separate from provider token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final tokenStorage = InMemoryAiTokenStorage();
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: tokenStorage,
      );

      await repository.saveSettings(
        const AiProviderSettings(
          provider: AiProvider.anthropic,
          model: 'claude-3-5-sonnet-latest',
        ),
      );
      await repository.saveToken('stored provider value');

      expect(
        preferences.getString(
          SharedPreferencesAiSettingsRepository.settingsKey,
        ),
        contains('anthropic'),
      );
      expect(
        preferences
            .getString(SharedPreferencesAiSettingsRepository.settingsKey)
            .toString(),
        isNot(contains('stored provider value')),
      );
      expect(
        preferences.getString(
          SharedPreferencesAiSettingsRepository.settingsKey,
        ),
        isNot(contains('FoodData')),
      );
      expect((await repository.loadTokenState()).hasToken, isTrue);

      final reloaded = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: tokenStorage,
      );

      expect((await reloaded.loadTokenState()).hasToken, isTrue);
    },
  );

  test(
    'shared preferences repository falls back for corrupt settings JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAiSettingsRepository.settingsKey: '{"provider":',
      });
      final preferences = await SharedPreferences.getInstance();
      final tokenStorage = InMemoryAiTokenStorage();
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: tokenStorage,
      );

      await repository.saveToken('stored provider value');
      final settings = await repository.loadSettings();

      expect(settings, AiProviderSettings.defaults);
      expect((await repository.loadTokenState()).hasToken, isTrue);
      expect(await repository.readProviderToken(), 'stored provider value');
      expect(
        preferences
            .getString(SharedPreferencesAiSettingsRepository.settingsKey)
            .toString(),
        isNot(contains('stored provider value')),
      );
    },
  );

  test(
    'shared preferences repository falls back for wrong settings shape',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAiSettingsRepository.settingsKey: '["openai"]',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: InMemoryAiTokenStorage(),
      );

      expect(await repository.loadSettings(), AiProviderSettings.defaults);
    },
  );

  test('real provider selection does not silently become mock mode', () async {
    const configuration = AiAdapterConfiguration(
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

    expect(configuration.canUseRealProvider, isFalse);
    expect(configuration.shouldUseMock, isFalse);
    expect(configuration.modeLabel, 'OpenAI needs token');
  });

  test(
    'shared preferences repository falls back for incompatible setting fields',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAiSettingsRepository.settingsKey:
            '{"provider": 123, "model": true}',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: InMemoryAiTokenStorage(),
      );

      expect(await repository.loadSettings(), AiProviderSettings.defaults);
    },
  );
}
