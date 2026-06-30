enum AiProvider { openai, gemini, anthropic }

class AiProviderOption {
  const AiProviderOption({
    required this.provider,
    required this.label,
    required this.latestModel,
    required this.requiresToken,
    required this.description,
    required this.tokenHelpText,
    required this.tokenUrl,
  });

  final AiProvider provider;
  final String label;
  final String latestModel;
  final bool requiresToken;
  final String description;
  final String tokenHelpText;
  final String tokenUrl;
}

class AiProviderCatalog {
  const AiProviderCatalog._();

  static const options = [
    AiProviderOption(
      provider: AiProvider.openai,
      label: 'OpenAI',
      latestModel: 'gpt-4.1-mini',
      requiresToken: true,
      description: 'Uses the current app-approved OpenAI model automatically.',
      tokenHelpText:
          'Create an OpenAI API key in the OpenAI dashboard, then save it here.',
      tokenUrl: 'https://platform.openai.com/api-keys',
    ),
    AiProviderOption(
      provider: AiProvider.gemini,
      label: 'Gemini',
      latestModel: 'gemini-1.5-flash-latest',
      requiresToken: true,
      description: 'Uses the current app-approved Gemini model automatically.',
      tokenHelpText:
          'Create a Gemini API key in Google AI Studio, then save it here.',
      tokenUrl: 'https://aistudio.google.com/app/apikey',
    ),
    AiProviderOption(
      provider: AiProvider.anthropic,
      label: 'Anthropic',
      latestModel: 'claude-3-5-haiku-latest',
      requiresToken: true,
      description:
          'Uses the current app-approved Anthropic model automatically.',
      tokenHelpText:
          'Create an Anthropic API key in the Anthropic Console, then save it here.',
      tokenUrl: 'https://console.anthropic.com/settings/keys',
    ),
  ];

  static AiProviderOption optionFor(AiProvider provider) {
    return options.firstWhere((option) => option.provider == provider);
  }

  static AiProvider providerFromName(String? name) {
    return AiProvider.values.firstWhere(
      (provider) => provider.name == name,
      orElse: () => AiProvider.openai,
    );
  }

  static String normalizeModel(AiProvider provider, String? _) {
    final option = optionFor(provider);
    return option.latestModel;
  }
}

class AiProviderSettings {
  const AiProviderSettings({
    this.provider = AiProvider.openai,
    this.model = 'gpt-4.1-mini',
  });

  final AiProvider provider;
  final String model;

  static const defaults = AiProviderSettings();

  AiProviderOption get option => AiProviderCatalog.optionFor(provider);

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

  String get providerLabel => settings.option.label;

  String get modeLabel {
    if (canUseRealProvider) {
      return '${settings.option.label} ready';
    }
    return '${settings.option.label} needs token';
  }
}
