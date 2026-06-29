import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/health.dart';
import '../../domain/models/onboarding.dart';
import '../../domain/repositories/ai_settings_repository.dart';
import '../../domain/repositories/health_repository.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_section_card.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({
    super.key,
    required this.profile,
    required this.aiSettingsRepository,
    required this.healthRepository,
    required this.healthState,
    required this.onAiSettingsChanged,
    required this.onHealthStateChanged,
    required this.onResetOnboarding,
  });

  final OnboardingProfile profile;
  final AiSettingsRepository aiSettingsRepository;
  final HealthRepository healthRepository;
  final HealthConnectionState healthState;
  final Future<void> Function() onAiSettingsChanged;
  final Future<void> Function() onHealthStateChanged;
  final Future<void> Function() onResetOnboarding;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late Future<_AiSettingsViewState> _aiSettingsFuture;
  late HealthConnectionState _healthState;
  final TextEditingController _tokenController = TextEditingController();
  AiProviderSettings? _draftSettings;
  String? _statusMessage;
  String? _healthStatusMessage;

  @override
  void initState() {
    super.initState();
    _aiSettingsFuture = _loadAiSettings();
    _healthState = widget.healthState;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthState != widget.healthState) {
      _healthState = widget.healthState;
    }
  }

  Future<_AiSettingsViewState> _loadAiSettings() async {
    final settings = await widget.aiSettingsRepository.loadSettings();
    final tokenState = await widget.aiSettingsRepository.loadTokenState();
    _draftSettings = settings;
    return _AiSettingsViewState(settings: settings, tokenState: tokenState);
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
            return _buildAiSettingsCard(context, snapshot.requireData);
          },
        ),
        const SizedBox(height: 16),
        _buildHealthConnectionCard(context),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Health and privacy',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health, camera, and token access remain off until a feature needs consent.',
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
          TextField(
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

  Future<void> _saveAiSettings() async {
    final settings = _draftSettings ?? AiProviderSettings.defaults;
    await widget.aiSettingsRepository.saveSettings(settings);
    await widget.onAiSettingsChanged();
    setState(() {
      _statusMessage = '${settings.option.label} ${settings.model} saved.';
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
      _aiSettingsFuture = _loadAiSettings();
    });
  }

  Future<void> _deleteToken() async {
    await widget.aiSettingsRepository.deleteToken();
    await widget.onAiSettingsChanged();
    setState(() {
      _tokenController.clear();
      _statusMessage = 'Token deleted from this device.';
      _aiSettingsFuture = _loadAiSettings();
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

class _AiSettingsViewState {
  const _AiSettingsViewState({
    required this.settings,
    required this.tokenState,
  });

  final AiProviderSettings settings;
  final AiTokenState tokenState;
}
