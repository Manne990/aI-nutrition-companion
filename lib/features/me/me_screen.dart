import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/auth.dart';
import '../../domain/models/diagnostics.dart';
import '../../domain/models/health.dart';
import '../../domain/models/onboarding.dart';
import '../../domain/repositories/ai_settings_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/health_repository.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_section_card.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    required this.profile,
    required this.aiSettingsRepository,
    required this.authRepository,
    required this.authState,
    required this.healthRepository,
    required this.healthState,
    required this.onAiSettingsChanged,
    required this.onAuthStateChanged,
    required this.onHealthStateChanged,
    required this.onResetOnboarding,
    this.diagnosticsConfig = const AppDiagnosticsConfig(),
    this.diagnosticsClipboard = const SystemDiagnosticsClipboard(),
  });

  final OnboardingProfile profile;
  final AiSettingsRepository aiSettingsRepository;
  final AuthRepository authRepository;
  final AuthAccountState authState;
  final HealthRepository healthRepository;
  final HealthConnectionState healthState;
  final Future<void> Function() onAiSettingsChanged;
  final Future<void> Function() onAuthStateChanged;
  final Future<void> Function() onHealthStateChanged;
  final Future<void> Function() onResetOnboarding;
  final AppDiagnosticsConfig diagnosticsConfig;
  final DiagnosticsClipboard diagnosticsClipboard;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late Future<_AiSettingsViewState> _aiSettingsFuture;
  late AuthAccountState _authState;
  late HealthConnectionState _healthState;
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _foodDataCentralKeyController =
      TextEditingController();
  AiProviderSettings? _draftSettings;
  String? _statusMessage;
  String? _credentialStatusMessage;
  String? _healthStatusMessage;
  String? _diagnosticsStatusMessage;

  @override
  void initState() {
    super.initState();
    _aiSettingsFuture = _loadAiSettings();
    _authState = widget.authState;
    _healthState = widget.healthState;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _foodDataCentralKeyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthState != widget.healthState) {
      _healthState = widget.healthState;
    }
    if (oldWidget.authState != widget.authState) {
      _authState = widget.authState;
    }
  }

  Future<_AiSettingsViewState> _loadAiSettings() async {
    final settings = await widget.aiSettingsRepository.loadSettings();
    final tokenState = await widget.aiSettingsRepository.loadTokenState();
    final foodDataCentralKeyState = await widget.aiSettingsRepository
        .loadFoodDataCentralKeyState();
    _draftSettings = settings;
    return _AiSettingsViewState(
      settings: settings,
      tokenState: tokenState,
      foodDataCentralKeyState: foodDataCentralKeyState,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Me', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Goals and preferences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.profile.primaryGoal),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppChip(
                    label:
                        '${widget.profile.proteinGoalGrams.round()}g protein',
                    icon: Icons.fitness_center,
                  ),
                  AppChip(
                    label: widget.profile.coachingTone,
                    icon: Icons.chat_bubble,
                  ),
                  for (final preference in widget.profile.dietaryPreferences)
                    AppChip(label: preference),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<_AiSettingsViewState>(
          future: _aiSettingsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AppSectionCard(
                title: 'AI provider',
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final viewState = snapshot.requireData;
            return Column(
              children: [
                _buildAiSettingsCard(context, viewState),
                const SizedBox(height: 16),
                _buildExternalCredentialsCard(context, viewState),
                const SizedBox(height: 16),
                _buildDiagnosticsCard(context, viewState),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildAccountCard(context),
        const SizedBox(height: 16),
        _buildHealthConnectionCard(context),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Privacy and safety disclosures',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DisclosureBullet(
                icon: Icons.health_and_safety_outlined,
                text:
                    'Nutrition guidance is practical wellness support, not medical diagnosis or treatment.',
              ),
              const _DisclosureBullet(
                icon: Icons.auto_awesome_outlined,
                text:
                    'AI and photo estimates can be wrong; confirm portions and ingredients before relying on totals.',
              ),
              const _DisclosureBullet(
                icon: Icons.lock_outline,
                text:
                    'Provider tokens and FoodData Central keys stay on this device and are never shown again after saving.',
              ),
              const _DisclosureBullet(
                icon: Icons.cloud_off_outlined,
                text:
                    'V1 is local-first with mock defaults, signed-out use, and no custom backend account sync.',
              ),
              const _DisclosureBullet(
                icon: Icons.camera_alt_outlined,
                text:
                    'Camera and health access stay off until you choose a feature that needs them.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: 'Reset onboarding',
                icon: Icons.restart_alt,
                onPressed: widget.onResetOnboarding,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSettingsCard(
    BuildContext context,
    _AiSettingsViewState viewState,
  ) {
    final settings = _draftSettings ?? viewState.settings;
    final option = settings.option;
    final tokenState = viewState.tokenState;

    return AppSectionCard(
      title: 'AI provider',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_providerStatus(settings, tokenState)),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<AiProvider>(
            initialValue: settings.provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: [
              for (final option in AiProviderCatalog.options)
                DropdownMenuItem(
                  value: option.provider,
                  child: Text(option.label),
                ),
            ],
            onChanged: (provider) {
              if (provider == null) {
                return;
              }
              setState(() {
                _draftSettings = settings.copyWith(
                  provider: provider,
                  model: AiProviderCatalog.optionFor(provider).defaultModel,
                );
                _statusMessage = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: settings.model,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final model in option.models)
                DropdownMenuItem(value: model, child: Text(model)),
            ],
            onChanged: (model) {
              if (model == null) {
                return;
              }
              setState(() {
                _draftSettings = settings.copyWith(model: model);
                _statusMessage = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Save AI settings',
            icon: Icons.save_outlined,
            onPressed: _saveAiSettings,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            option.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Real provider mode may send prompts and nutrition context to the selected provider when networking is enabled. Mock AI stays local for default use and tests.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: tokenState.hasToken ? 'Token saved' : 'No token saved',
                icon: tokenState.hasToken
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                tone: tokenState.hasToken
                    ? AppChipTone.success
                    : AppChipTone.neutral,
              ),
              AppChip(
                label: tokenState.isSecureStorage
                    ? 'Secure local storage'
                    : 'Storage fallback',
                icon: Icons.security,
                tone: tokenState.isSecureStorage
                    ? AppChipTone.success
                    : AppChipTone.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Save only a user-owned provider token. It is stored locally, never displayed after saving, and can be deleted here.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('ai-provider-token-field'),
            controller: _tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Provider token',
              hintText: 'Paste token to save locally',
              helperText: 'Saved tokens are never shown again.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: tokenState.hasToken ? 'Update token' : 'Save token',
                  icon: Icons.key,
                  onPressed: _saveToken,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Delete token',
                  icon: Icons.delete_outline,
                  onPressed: tokenState.hasToken ? _deleteToken : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tokenState.errorMessage ??
                'The token is stored separately from provider settings in ${tokenState.storageLabel}. Delete token removes the local copy from this device.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppChip(
              label: _statusMessage!,
              icon: Icons.check_circle_outline,
              tone: AppChipTone.success,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExternalCredentialsCard(
    BuildContext context,
    _AiSettingsViewState viewState,
  ) {
    final keyState = viewState.foodDataCentralKeyState;

    return AppSectionCard(
      title: 'External service credentials',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FoodData Central can use a user-provided API key for direct lookup. Open Food Facts does not need credentials for the read path.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: keyState.hasKey
                    ? 'FoodData Central key saved'
                    : 'No FoodData Central key',
                icon: keyState.hasKey
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                tone: keyState.hasKey
                    ? AppChipTone.success
                    : AppChipTone.neutral,
              ),
              AppChip(
                label: keyState.isSecureStorage
                    ? 'Secure local storage'
                    : 'Storage fallback',
                icon: Icons.security,
                tone: keyState.isSecureStorage
                    ? AppChipTone.success
                    : AppChipTone.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('fooddata-central-api-key-field'),
            controller: _foodDataCentralKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'FoodData Central API key',
              hintText: 'Paste key to save locally',
              helperText: 'Saved keys are never shown again.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: keyState.hasKey
                      ? 'Update FoodData Central key'
                      : 'Save FoodData Central key',
                  icon: Icons.key,
                  onPressed: _saveFoodDataCentralKey,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Delete FoodData Central key',
                  icon: Icons.delete_outline,
                  onPressed: keyState.hasKey ? _deleteFoodDataCentralKey : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            keyState.errorMessage ??
                'The FoodData Central key is stored separately from app preferences in ${keyState.storageLabel}. Delete key removes the local copy from this device.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          if (_credentialStatusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppChip(
              label: _credentialStatusMessage!,
              icon: Icons.check_circle_outline,
              tone: AppChipTone.success,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthConnectionCard(BuildContext context) {
    final healthState = _healthState;
    final signalLabels = _signalLabels(healthState.signals);
    final enabledLabels = healthState.enabledTypes
        .map((type) => type.label)
        .toList(growable: false);

    return AppSectionCard(
      title: 'Health connection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(healthState.explainer),
          if (healthState.statusDetail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              healthState.statusDetail!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: healthState.statusLabel,
                icon: _healthStatusIcon(healthState.status),
                tone: _healthStatusTone(healthState.status),
              ),
              AppChip(
                label: healthState.providerLabel,
                icon: Icons.health_and_safety_outlined,
              ),
              for (final label in enabledLabels)
                AppChip(label: label, icon: Icons.check_circle_outline),
              for (final label in signalLabels) AppChip(label: label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Health signals are optional context for meal suggestions, not a medical record or care plan.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: AppSpacing.md),
          if (healthState.isConnected)
            AppSecondaryButton(
              label: 'Disconnect health',
              icon: Icons.link_off,
              onPressed: _disconnectHealth,
            )
          else
            AppPrimaryButton(
              label: 'Connect health',
              icon: Icons.health_and_safety_outlined,
              onPressed:
                  healthState.status == HealthConnectionStatus.unavailable
                  ? null
                  : _connectHealth,
            ),
          if (_healthStatusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppChip(
              label: _healthStatusMessage!,
              icon: Icons.info_outline,
              tone: AppChipTone.accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final authState = _authState;

    return AppSectionCard(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(authState.explainer),
          if (authState.statusDetail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              authState.statusDetail!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: authState.statusLabel,
                icon: _authStatusIcon(authState.status),
                tone: _authStatusTone(authState.status),
              ),
              AppChip(
                label: authState.provider.label,
                icon: Icons.account_circle_outlined,
              ),
              if (authState.userLabel != null)
                AppChip(
                  label: authState.userLabel!,
                  icon: Icons.person_outline,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (authState.isSignedIn)
            AppSecondaryButton(
              label: 'Sign out',
              icon: Icons.logout,
              onPressed: _signOut,
            )
          else
            AppPrimaryButton(
              label: 'Use mock account',
              icon: Icons.login,
              onPressed: _signInWithMock,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Firebase Auth or Supabase Auth can replace this boundary later. V1 does not include a real auth project, custom backend, or nutrition sync.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(
    BuildContext context,
    _AiSettingsViewState viewState,
  ) {
    return AppSectionCard(
      title: 'Feedback and diagnostics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Copy a local support report with app version, provider modes, and high-level feature state. Tokens and API keys are never included.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Copy diagnostics',
            icon: Icons.content_copy,
            onPressed: () => _copyDiagnostics(viewState),
          ),
          if (_diagnosticsStatusMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppChip(
              label: _diagnosticsStatusMessage!,
              icon: Icons.check_circle_outline,
              tone: AppChipTone.success,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveAiSettings() async {
    final settings = _draftSettings ?? AiProviderSettings.defaults;
    await widget.aiSettingsRepository.saveSettings(settings);
    await widget.onAiSettingsChanged();
    setState(() {
      _statusMessage = '${settings.option.label} ${settings.model} saved.';
      _credentialStatusMessage = null;
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _statusMessage = 'Enter a token before saving.';
      });
      return;
    }
    await widget.aiSettingsRepository.saveToken(token);
    await widget.onAiSettingsChanged();
    setState(() {
      _tokenController.clear();
      _statusMessage = 'Token saved locally.';
      _credentialStatusMessage = null;
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _deleteToken() async {
    await widget.aiSettingsRepository.deleteToken();
    await widget.onAiSettingsChanged();
    setState(() {
      _tokenController.clear();
      _statusMessage = 'Token deleted from this device.';
      _credentialStatusMessage = null;
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _saveFoodDataCentralKey() async {
    final apiKey = _foodDataCentralKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _credentialStatusMessage =
            'Enter a FoodData Central key before saving.';
        _statusMessage = null;
      });
      return;
    }
    await widget.aiSettingsRepository.saveFoodDataCentralKey(apiKey);
    await widget.onAiSettingsChanged();
    setState(() {
      _foodDataCentralKeyController.clear();
      _credentialStatusMessage = 'FoodData Central key saved locally.';
      _statusMessage = null;
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _deleteFoodDataCentralKey() async {
    await widget.aiSettingsRepository.deleteFoodDataCentralKey();
    await widget.onAiSettingsChanged();
    setState(() {
      _foodDataCentralKeyController.clear();
      _credentialStatusMessage =
          'FoodData Central key deleted from this device.';
      _statusMessage = null;
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _signInWithMock() async {
    final nextState = await widget.authRepository.signInWithMock();
    await widget.onAuthStateChanged();
    setState(() {
      _authState = nextState;
    });
  }

  Future<void> _signOut() async {
    final nextState = await widget.authRepository.signOut();
    await widget.onAuthStateChanged();
    setState(() {
      _authState = nextState;
    });
  }

  Future<void> _connectHealth() async {
    final nextState = await widget.healthRepository.requestConnection();
    await widget.onHealthStateChanged();
    setState(() {
      _healthState = nextState;
      _healthStatusMessage = switch (nextState.status) {
        HealthConnectionStatus.connected => 'Health connection enabled.',
        HealthConnectionStatus.denied => 'Health permission denied.',
        HealthConnectionStatus.unavailable => 'Health connection unavailable.',
        HealthConnectionStatus.disconnected => 'Health connection remains off.',
      };
    });
  }

  Future<void> _disconnectHealth() async {
    final nextState = await widget.healthRepository.disconnect();
    await widget.onHealthStateChanged();
    setState(() {
      _healthState = nextState;
      _healthStatusMessage = 'Health connection disconnected.';
    });
  }

  Future<void> _copyDiagnostics(_AiSettingsViewState viewState) async {
    final snapshot = AppDiagnosticsSnapshot(
      config: widget.diagnosticsConfig,
      profile: widget.profile,
      aiSettings: viewState.settings,
      aiTokenState: viewState.tokenState,
      foodDataCentralKeyState: viewState.foodDataCentralKeyState,
      authState: _authState,
      healthState: _healthState,
    );
    await widget.diagnosticsClipboard.copy(snapshot.exportText());
    setState(() {
      _diagnosticsStatusMessage =
          'Diagnostics copied locally. Paste it only when you choose.';
    });
  }

  String _providerStatus(AiProviderSettings settings, AiTokenState tokenState) {
    if (settings.usesMockProvider) {
      return 'Mock AI is the default for tests and local CI. No token is required.';
    }
    if (tokenState.hasToken) {
      return '${settings.option.label} is selected with ${settings.model}. Real calls remain stubbed behind the adapter until provider networking is added.';
    }
    return '${settings.option.label} is selected with ${settings.model}. Add a token before real provider mode can be used.';
  }
}

List<String> _signalLabels(HealthSignalSnapshot? signals) {
  if (signals == null || !signals.hasSignals) {
    return const [];
  }
  return [
    if (signals.weightKg != null) '${signals.weightKg!.toStringAsFixed(1)} kg',
    if (signals.activeMinutes != null) '${signals.activeMinutes} min active',
    if (signals.workoutCount != null) '${signals.workoutCount} workout',
    if (signals.sleepHours != null)
      '${signals.sleepHours!.toStringAsFixed(1)}h sleep',
  ];
}

IconData _healthStatusIcon(HealthConnectionStatus status) {
  return switch (status) {
    HealthConnectionStatus.connected => Icons.check_circle_outline,
    HealthConnectionStatus.disconnected => Icons.radio_button_unchecked,
    HealthConnectionStatus.denied => Icons.block,
    HealthConnectionStatus.unavailable => Icons.error_outline,
  };
}

AppChipTone _healthStatusTone(HealthConnectionStatus status) {
  return switch (status) {
    HealthConnectionStatus.connected => AppChipTone.success,
    HealthConnectionStatus.disconnected => AppChipTone.neutral,
    HealthConnectionStatus.denied => AppChipTone.accent,
    HealthConnectionStatus.unavailable => AppChipTone.accent,
  };
}

IconData _authStatusIcon(AuthConnectionStatus status) {
  return switch (status) {
    AuthConnectionStatus.signedOut => Icons.radio_button_unchecked,
    AuthConnectionStatus.signedIn => Icons.check_circle_outline,
    AuthConnectionStatus.providerUnavailable => Icons.error_outline,
  };
}

AppChipTone _authStatusTone(AuthConnectionStatus status) {
  return switch (status) {
    AuthConnectionStatus.signedOut => AppChipTone.neutral,
    AuthConnectionStatus.signedIn => AppChipTone.success,
    AuthConnectionStatus.providerUnavailable => AppChipTone.accent,
  };
}

class _AiSettingsViewState {
  const _AiSettingsViewState({
    required this.settings,
    required this.tokenState,
    required this.foodDataCentralKeyState,
  });

  final AiProviderSettings settings;
  final AiTokenState tokenState;
  final FoodDataCentralKeyState foodDataCentralKeyState;
}

class _DisclosureBullet extends StatelessWidget {
  const _DisclosureBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.deepGreen),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

abstract interface class DiagnosticsClipboard {
  Future<void> copy(String text);
}

class SystemDiagnosticsClipboard implements DiagnosticsClipboard {
  const SystemDiagnosticsClipboard();

  @override
  Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
