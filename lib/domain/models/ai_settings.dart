enum AiProvider { mock, openai, anthropic }

class AiProviderOption {
  const AiProviderOption({
    required this.provider,
    required this.label,
    required this.models,
    required this.requiresToken,
    required this.description,
  });

  final AiProvider provider;
  final String label;
  final List<String> models;
  final bool requiresToken;
  final String description;

  String get defaultModel => models.first;
}

class AiProviderCatalog {
  const AiProviderCatalog._();

  static const options = [
    AiProviderOption(
      provider: AiProvider.mock,
      label: 'Mock AI',
      models: ['mock-companion-v1'],
      requiresToken: false,
      description: 'Deterministic local responses for tests and development.',
    ),
    AiProviderOption(
      provider: AiProvider.openai,
      label: 'OpenAI',
      models: ['gpt-4.1-mini', 'gpt-4.1'],
      requiresToken: true,
      description: 'Real-provider mode with your locally stored token.',
    ),
    AiProviderOption(
      provider: AiProvider.anthropic,
      label: 'Anthropic',
      models: ['claude-3-5-haiku-latest', 'claude-3-5-sonnet-latest'],
      requiresToken: true,
      description: 'Real-provider mode with your locally stored token.',
    ),
  ];

  static AiProviderOption optionFor(AiProvider provider) {
    return options.firstWhere((option) => option.provider == provider);
  }

  static AiProvider providerFromName(String? name) {
    return AiProvider.values.firstWhere(
      (provider) => provider.name == name,
      orElse: () => AiProvider.mock,
    );
  }

  static String normalizeModel(AiProvider provider, String? model) {
    final option = optionFor(provider);
    if (model != null && option.models.contains(model)) {
      return model;
    }
    return option.defaultModel;
  }
}

class AiProviderSettings {
  const AiProviderSettings({
    this.provider = AiProvider.mock,
    this.model = 'mock-companion-v1',
  });

  final AiProvider provider;
  final String model;

  static const defaults = AiProviderSettings();

  AiProviderOption get option => AiProviderCatalog.optionFor(provider);

  bool get usesMockProvider => provider == AiProvider.mock;

  bool get requiresToken => option.requiresToken;

  AiProviderSettings normalized() {
    return AiProviderSettings(
      provider: provider,
      model: AiProviderCatalog.normalizeModel(provider, model),
    );
  }

  AiProviderSettings copyWith({AiProvider? provider, String? model}) {
    final nextProvider = provider ?? this.provider;
    return AiProviderSettings(
      provider: nextProvider,
      model: AiProviderCatalog.normalizeModel(
        nextProvider,
        model ?? this.model,
      ),
    );
  }

  Map<String, Object?> toJson() {
    final normalizedSettings = normalized();
    return {
      'provider': normalizedSettings.provider.name,
      'model': normalizedSettings.model,
    };
  }

  factory AiProviderSettings.fromJson(Map<String, Object?> json) {
    final provider = AiProviderCatalog.providerFromName(
      json['provider'] as String?,
    );
    return AiProviderSettings(
      provider: provider,
      model: AiProviderCatalog.normalizeModel(
        provider,
        json['model'] as String?,
      ),
    );
  }
}

class AiTokenState {
  const AiTokenState({
    required this.hasToken,
    required this.isSecureStorage,
    required this.storageLabel,
    this.errorMessage,
  });

  final bool hasToken;
  final bool isSecureStorage;
  final String storageLabel;
  final String? errorMessage;

  bool get isAvailable => errorMessage == null;
}

class AiAdapterConfiguration {
  const AiAdapterConfiguration({
    required this.settings,
    required this.tokenState,
  });

  final AiProviderSettings settings;
  final AiTokenState tokenState;

  bool get canUseRealProvider =>
      settings.requiresToken && tokenState.hasToken && tokenState.isAvailable;

  bool get shouldUseMock => settings.usesMockProvider;

  String get providerLabel => settings.option.label;

  String get modeLabel {
    if (settings.usesMockProvider) {
      return 'Mock mode';
    }
    if (canUseRealProvider) {
      return '${settings.option.label} ready';
    }
    return '${settings.option.label} needs token';
  }
}
