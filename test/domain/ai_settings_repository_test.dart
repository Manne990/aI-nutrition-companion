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
    'in-memory repository creates, updates, and deletes token state',
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

      await repository.saveToken('updated provider value');
      expect((await repository.loadTokenState()).hasToken, isTrue);

      await repository.deleteToken();
      expect((await repository.loadTokenState()).hasToken, isFalse);

      expect((await repository.loadFoodDataCentralKeyState()).hasKey, isFalse);

      await repository.saveFoodDataCentralKey(' entered nutrition value ');
      expect((await repository.loadFoodDataCentralKeyState()).hasKey, isTrue);

      await repository.saveFoodDataCentralKey('updated nutrition value');
      expect((await repository.loadFoodDataCentralKeyState()).hasKey, isTrue);

      await repository.deleteFoodDataCentralKey();
      expect((await repository.loadFoodDataCentralKeyState()).hasKey, isFalse);
    },
  );

  test(
    'shared preferences repository keeps settings separate from credentials',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final tokenStorage = InMemoryAiTokenStorage();
      final foodDataCentralKeyStorage = InMemoryAiTokenStorage(
        storageLabel: 'in-memory nutrition key storage',
      );
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: tokenStorage,
        foodDataCentralKeyStorage: foodDataCentralKeyStorage,
      );

      await repository.saveSettings(
        const AiProviderSettings(
          provider: AiProvider.anthropic,
          model: 'claude-3-5-sonnet-latest',
        ),
      );
      await repository.saveToken('stored provider value');
      await repository.saveFoodDataCentralKey('stored nutrition value');

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
        preferences
            .getString(SharedPreferencesAiSettingsRepository.settingsKey)
            .toString(),
        isNot(contains('stored nutrition value')),
      );
      expect((await repository.loadTokenState()).hasToken, isTrue);
      expect((await repository.loadFoodDataCentralKeyState()).hasKey, isTrue);

      final reloaded = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: tokenStorage,
        foodDataCentralKeyStorage: foodDataCentralKeyStorage,
      );

      expect((await reloaded.loadTokenState()).hasToken, isTrue);
      expect((await reloaded.loadFoodDataCentralKeyState()).hasKey, isTrue);
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

  test(
    'shared preferences repository falls back when credential storage fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAiSettingsRepository(
        preferences,
        tokenStorage: InMemoryAiTokenStorage(),
        foodDataCentralKeyStorage: _ThrowingAiTokenStorage(),
      );

      final keyState = await repository.loadFoodDataCentralKeyState();

      expect(keyState.hasKey, isFalse);
      expect(keyState.isAvailable, isFalse);
      expect(
        keyState.errorMessage,
        contains('FoodData Central key storage is unavailable'),
      );
    },
  );
}

class _ThrowingAiTokenStorage implements AiTokenStorage {
  @override
  bool get isSecureStorage => true;

  @override
  String get storageLabel => 'broken secure storage';

  @override
  Future<String?> readToken() {
    throw StateError('corrupted secure storage payload');
  }

  @override
  Future<void> writeToken(String token) async {}

  @override
  Future<void> deleteToken() async {}
}
