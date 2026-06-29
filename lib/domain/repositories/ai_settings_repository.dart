import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_settings.dart';
import 'persisted_json.dart';

abstract interface class AiSettingsRepository {
  Future<AiProviderSettings> loadSettings();

  Future<void> saveSettings(AiProviderSettings settings);

  Future<AiTokenState> loadTokenState();

  Future<void> saveToken(String token);

  Future<void> deleteToken();

  Future<AiAdapterConfiguration> loadAdapterConfiguration();
}

abstract interface class AiTokenStorage {
  bool get isSecureStorage;

  String get storageLabel;

  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class FlutterSecureAiTokenStorage implements AiTokenStorage {
  const FlutterSecureAiTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'ai.provider.token.v1';

  final FlutterSecureStorage _storage;

  @override
  bool get isSecureStorage => true;

  @override
  String get storageLabel => 'platform secure storage';

  @override
  Future<String?> readToken() {
    return _storage.read(key: tokenKey);
  }

  @override
  Future<void> writeToken(String token) {
    return _storage.write(key: tokenKey, value: token);
  }

  @override
  Future<void> deleteToken() {
    return _storage.delete(key: tokenKey);
  }
}

class SharedPreferencesAiSettingsRepository implements AiSettingsRepository {
  const SharedPreferencesAiSettingsRepository(
    this._preferences, {
    required this.tokenStorage,
  });

  static const settingsKey = 'ai.provider.settings.v1';

  final SharedPreferences _preferences;
  final AiTokenStorage tokenStorage;

  static Future<SharedPreferencesAiSettingsRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAiSettingsRepository(
      preferences,
      tokenStorage: const FlutterSecureAiTokenStorage(),
    );
  }

  @override
  Future<AiProviderSettings> loadSettings() async {
    final rawSettings = _preferences.getString(settingsKey);
    if (rawSettings == null || rawSettings.isEmpty) {
      return AiProviderSettings.defaults;
    }

    final decoded = decodePersistedJsonMap(rawSettings);
    if (decoded == null) {
      return AiProviderSettings.defaults;
    }

    try {
      return AiProviderSettings.fromJson(decoded).normalized();
    } on TypeError {
      return AiProviderSettings.defaults;
    }
  }

  @override
  Future<void> saveSettings(AiProviderSettings settings) async {
    await _preferences.setString(
      settingsKey,
      jsonEncode(settings.normalized().toJson()),
    );
  }

  @override
  Future<AiTokenState> loadTokenState() async {
    try {
      final token = await tokenStorage.readToken();
      return AiTokenState(
        hasToken: token != null && token.isNotEmpty,
        isSecureStorage: tokenStorage.isSecureStorage,
        storageLabel: tokenStorage.storageLabel,
      );
    } catch (error) {
      return AiTokenState(
        hasToken: false,
        isSecureStorage: tokenStorage.isSecureStorage,
        storageLabel: tokenStorage.storageLabel,
        errorMessage: 'Token storage is unavailable: $error',
      );
    }
  }

  @override
  Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await deleteToken();
      return;
    }
    await tokenStorage.writeToken(trimmed);
  }

  @override
  Future<void> deleteToken() {
    return tokenStorage.deleteToken();
  }

  @override
  Future<AiAdapterConfiguration> loadAdapterConfiguration() async {
    return AiAdapterConfiguration(
      settings: await loadSettings(),
      tokenState: await loadTokenState(),
    );
  }
}

class InMemoryAiTokenStorage implements AiTokenStorage {
  InMemoryAiTokenStorage({
    this.isSecureStorage = true,
    this.storageLabel = 'in-memory secure test storage',
  });

  String? _token;

  @override
  final bool isSecureStorage;

  @override
  final String storageLabel;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

class InMemoryAiSettingsRepository implements AiSettingsRepository {
  InMemoryAiSettingsRepository({
    AiProviderSettings settings = AiProviderSettings.defaults,
    AiTokenStorage? tokenStorage,
  }) : _settings = settings.normalized(),
       _tokenStorage = tokenStorage ?? InMemoryAiTokenStorage();

  AiProviderSettings _settings;
  final AiTokenStorage _tokenStorage;

  @override
  Future<AiProviderSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AiProviderSettings settings) async {
    _settings = settings.normalized();
  }

  @override
  Future<AiTokenState> loadTokenState() async {
    final token = await _tokenStorage.readToken();
    return AiTokenState(
      hasToken: token != null && token.isNotEmpty,
      isSecureStorage: _tokenStorage.isSecureStorage,
      storageLabel: _tokenStorage.storageLabel,
    );
  }

  @override
  Future<void> saveToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await deleteToken();
      return;
    }
    await _tokenStorage.writeToken(trimmed);
  }

  @override
  Future<void> deleteToken() {
    return _tokenStorage.deleteToken();
  }

  @override
  Future<AiAdapterConfiguration> loadAdapterConfiguration() async {
    return AiAdapterConfiguration(
      settings: await loadSettings(),
      tokenState: await loadTokenState(),
    );
  }
}
