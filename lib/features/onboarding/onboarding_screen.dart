import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/auth.dart';
import '../../domain/models/nutrition.dart';
import '../../domain/models/onboarding.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_section_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
    this.initialAccount,
    this.initialAiSettings = AiProviderSettings.defaults,
    this.aiTokenState = const AiTokenState(
      hasToken: false,
      isSecureStorage: true,
      storageLabel: 'platform secure storage',
    ),
    this.onAccountDetailsSaved,
    this.onAiSettingsSaved,
  });

  final ValueChanged<OnboardingProfile> onCompleted;
  final LocalAccountRecord? initialAccount;
  final AiProviderSettings initialAiSettings;
  final AiTokenState aiTokenState;
  final Future<void> Function({
    required String email,
    required String displayName,
  })?
  onAccountDetailsSaved;
  final Future<void> Function({
    required AiProviderSettings settings,
    String? token,
  })?
  onAiSettingsSaved;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _lastStep = 5;

  final _controller = PageController();
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  final _allergyController = TextEditingController();
  final _dislikedController = TextEditingController();
  final _proteinController = TextEditingController(text: '110');
  final _targetWeightController = TextEditingController();
  final _aiTokenController = TextEditingController();

  int _step = 0;
  String _primaryGoal = 'Build steady high-protein habits';
  String _coachingTone = 'calm and practical';
  late AiProviderSettings _aiSettings;
  bool _acceptedNutrition = false;
  bool _acceptedAi = false;
  bool _acceptedPrivacy = false;
  LocalDataBackupPreference _backupPreference =
      LocalDataBackupPreference.localOnly;
  bool _healthConnectionApproved = false;
  final Set<String> _dietaryPreferences = {'high protein'};

  bool get _canFinish => _acceptedNutrition && _acceptedAi && _acceptedPrivacy;

  bool get _canContinue {
    if (_step == 0) {
      return _looksLikeEmail(_emailController.text) &&
          _nameController.text.trim().isNotEmpty;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    _emailController = TextEditingController(text: account?.normalizedEmail);
    _nameController = TextEditingController(text: account?.displayName);
    _emailController.addListener(_handleAccountDetailsChanged);
    _nameController.addListener(_handleAccountDetailsChanged);
    _aiSettings = widget.initialAiSettings.normalized();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.removeListener(_handleAccountDetailsChanged);
    _nameController.removeListener(_handleAccountDetailsChanged);
    _emailController.dispose();
    _nameController.dispose();
    _allergyController.dispose();
    _dislikedController.dispose();
    _proteinController.dispose();
    _targetWeightController.dispose();
    _aiTokenController.dispose();
    super.dispose();
  }

  void _handleAccountDetailsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI Nutrition Companion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${_step + 1} / ${_lastStep + 1}',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (step) => setState(() => _step = step),
                children: [
                  _AccountDetailsStep(
                    emailController: _emailController,
                    nameController: _nameController,
                  ),
                  _GoalStep(
                    selectedGoal: _primaryGoal,
                    onSelected: (goal) => setState(() => _primaryGoal = goal),
                  ),
                  _FoodBoundaryStep(
                    dietaryPreferences: _dietaryPreferences,
                    allergyController: _allergyController,
                    dislikedController: _dislikedController,
                    onPreferenceToggled: _toggleDietaryPreference,
                  ),
                  _TargetStep(
                    proteinController: _proteinController,
                    targetWeightController: _targetWeightController,
                    selectedTone: _coachingTone,
                    onToneSelected: (tone) {
                      setState(() => _coachingTone = tone);
                    },
                  ),
                  _AiProviderStep(
                    settings: _aiSettings,
                    tokenState: widget.aiTokenState,
                    tokenController: _aiTokenController,
                    onProviderChanged: (provider) {
                      setState(() {
                        _aiSettings = _aiSettings.copyWith(provider: provider);
                      });
                    },
                  ),
                  _ConsentStep(
                    backupPreference: _backupPreference,
                    healthConnectionApproved: _healthConnectionApproved,
                    acceptedNutrition: _acceptedNutrition,
                    acceptedAi: _acceptedAi,
                    acceptedPrivacy: _acceptedPrivacy,
                    onBackupPreferenceChanged: (preference) {
                      setState(() => _backupPreference = preference);
                    },
                    onHealthConnectionChanged: (value) {
                      setState(() => _healthConnectionApproved = value);
                    },
                    onNutritionChanged: (value) {
                      setState(() => _acceptedNutrition = value);
                    },
                    onAiChanged: (value) {
                      setState(() => _acceptedAi = value);
                    },
                    onPrivacyChanged: (value) {
                      setState(() => _acceptedPrivacy = value);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Back',
                        onPressed: _goBack,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (_step == 2 || _step == 3) ...[
                    AppSecondaryButton(label: 'Skip', onPressed: _goNext),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: _step == _lastStep ? 'Start Today' : 'Continue',
                      onPressed:
                          (!_canContinue || (_step == _lastStep && !_canFinish))
                          ? null
                          : (_step == _lastStep ? _complete : _goNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDietaryPreference(String preference) {
    setState(() {
      if (!_dietaryPreferences.add(preference)) {
        _dietaryPreferences.remove(preference);
      }
    });
  }

  void _goBack() {
    final nextStep = (_step - 1).clamp(0, _lastStep);
    _controller.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    final nextStep = (_step + 1).clamp(0, _lastStep);
    _controller.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _complete() async {
    await widget.onAccountDetailsSaved?.call(
      email: _emailController.text,
      displayName: _nameController.text,
    );
    await widget.onAiSettingsSaved?.call(
      settings: _aiSettings,
      token: _aiTokenController.text,
    );
    widget.onCompleted(
      OnboardingProfile(
        primaryGoal: _primaryGoal,
        proteinGoalGrams: _parseNumber(_proteinController.text, fallback: 110),
        targetWeightKg: _parseOptionalNumber(_targetWeightController.text),
        dietaryPreferences: _dietaryPreferences.toList()..sort(),
        allergies: _splitList(_allergyController.text),
        dislikedFoods: _splitList(_dislikedController.text),
        coachingTone: _coachingTone,
        acceptedNutritionDisclaimer: _acceptedNutrition,
        acceptedAiGuidanceDisclaimer: _acceptedAi,
        acceptedPrivacyBoundary: _acceptedPrivacy,
        completedAt: DateTime.now(),
        backupPreference: _backupPreference,
        healthConnectionApproved: _healthConnectionApproved,
      ),
    );
  }
}

class _AccountDetailsStep extends StatelessWidget {
  const _AccountDetailsStep({
    required this.emailController,
    required this.nameController,
  });

  final TextEditingController emailController;
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Account details',
      children: [
        const Text('Confirm the local account used for this profile.'),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          key: const Key('onboarding-account-email-field'),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Account email',
            hintText: 'you@example.com',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('onboarding-account-name-field'),
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'Your name',
          ),
        ),
      ],
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selectedGoal, required this.onSelected});

  final String selectedGoal;
  final ValueChanged<String> onSelected;

  static const goals = [
    'Build steady high-protein habits',
    'Lose weight steadily',
    'Build muscle',
    'Feel energized through the day',
  ];

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Set your direction',
      children: [
        const Text('Choose the goal the companion should optimize for first.'),
        const SizedBox(height: AppSpacing.lg),
        for (final goal in goals) ...[
          _SelectableTile(
            title: goal,
            selected: goal == selectedGoal,
            onTap: () => onSelected(goal),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _FoodBoundaryStep extends StatelessWidget {
  const _FoodBoundaryStep({
    required this.dietaryPreferences,
    required this.allergyController,
    required this.dislikedController,
    required this.onPreferenceToggled,
  });

  final Set<String> dietaryPreferences;
  final TextEditingController allergyController;
  final TextEditingController dislikedController;
  final ValueChanged<String> onPreferenceToggled;

  static const preferences = [
    'high protein',
    'vegetarian',
    'dairy-free',
    'gluten-free',
    'low prep',
  ];

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Food boundaries',
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preference in preferences)
              FilterChip(
                label: Text(preference),
                selected: dietaryPreferences.contains(preference),
                onSelected: (_) => onPreferenceToggled(preference),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: allergyController,
          decoration: const InputDecoration(
            labelText: 'Allergies or intolerances',
            hintText: 'peanuts, shellfish',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: dislikedController,
          decoration: const InputDecoration(
            labelText: 'Foods to avoid',
            hintText: 'raw onion, olives',
          ),
        ),
      ],
    );
  }
}

class _TargetStep extends StatelessWidget {
  const _TargetStep({
    required this.proteinController,
    required this.targetWeightController,
    required this.selectedTone,
    required this.onToneSelected,
  });

  final TextEditingController proteinController;
  final TextEditingController targetWeightController;
  final String selectedTone;
  final ValueChanged<String> onToneSelected;

  static const tones = [
    'calm and practical',
    'direct and brief',
    'encouraging',
  ];

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Targets and tone',
      children: [
        TextField(
          controller: proteinController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Protein target',
            suffixText: 'g/day',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: targetWeightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target weight',
            suffixText: 'kg',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tone in tones)
              ChoiceChip(
                label: Text(tone),
                selected: selectedTone == tone,
                onSelected: (_) => onToneSelected(tone),
              ),
          ],
        ),
      ],
    );
  }
}

class _ConsentStep extends StatelessWidget {
  const _ConsentStep({
    required this.backupPreference,
    required this.healthConnectionApproved,
    required this.acceptedNutrition,
    required this.acceptedAi,
    required this.acceptedPrivacy,
    required this.onBackupPreferenceChanged,
    required this.onHealthConnectionChanged,
    required this.onNutritionChanged,
    required this.onAiChanged,
    required this.onPrivacyChanged,
  });

  final LocalDataBackupPreference backupPreference;
  final bool healthConnectionApproved;
  final bool acceptedNutrition;
  final bool acceptedAi;
  final bool acceptedPrivacy;
  final ValueChanged<LocalDataBackupPreference> onBackupPreferenceChanged;
  final ValueChanged<bool> onHealthConnectionChanged;
  final ValueChanged<bool> onNutritionChanged;
  final ValueChanged<bool> onAiChanged;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Consent boundaries',
      children: [
        const AppSectionCard(
          title: 'Before AI guidance',
          child: Text(
            'Nutrition guidance is general wellness support, not medical care. AI estimates can be wrong, and you can correct or ignore them.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: 'Local data backup',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<LocalDataBackupPreference>(
                segments: const [
                  ButtonSegment(
                    value: LocalDataBackupPreference.localOnly,
                    label: Text('Local only'),
                    icon: Icon(Icons.cloud_off_outlined),
                  ),
                  ButtonSegment(
                    value: LocalDataBackupPreference.platformBackupAllowed,
                    label: Text('Allow backup'),
                    icon: Icon(Icons.cloud_done_outlined),
                  ),
                ],
                selected: {backupPreference},
                onSelectionChanged: (selection) {
                  onBackupPreferenceChanged(selection.single);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(backupPreference.description),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          value: healthConnectionApproved,
          onChanged: (value) => onHealthConnectionChanged(value ?? false),
          title: const Text('Connect Health for nutrition context.'),
          subtitle: const Text(
            'Health is optional and is never used for diagnosis or treatment.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        _ConsentCheckbox(
          value: acceptedNutrition,
          label: 'I understand nutrition guidance is not medical advice.',
          onChanged: onNutritionChanged,
        ),
        _ConsentCheckbox(
          value: acceptedAi,
          label: 'I understand AI meal and macro estimates may be uncertain.',
          onChanged: onAiChanged,
        ),
        _ConsentCheckbox(
          value: acceptedPrivacy,
          label:
              'Camera, health, and token access stay off until I choose a feature that needs them.',
          onChanged: onPrivacyChanged,
        ),
      ],
    );
  }
}

class _AiProviderStep extends StatelessWidget {
  const _AiProviderStep({
    required this.settings,
    required this.tokenState,
    required this.tokenController,
    required this.onProviderChanged,
  });

  final AiProviderSettings settings;
  final AiTokenState tokenState;
  final TextEditingController tokenController;
  final ValueChanged<AiProvider> onProviderChanged;

  @override
  Widget build(BuildContext context) {
    final option = settings.option;
    return _StepBody(
      title: 'AI provider',
      children: [
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
            if (provider != null) {
              onProviderChanged(provider);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppChip(
          label: 'Latest model: ${option.latestModel}',
          icon: Icons.auto_awesome_outlined,
          tone: AppChipTone.accent,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${option.tokenHelpText} Token page: ${option.tokenUrl}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: AppSpacing.md),
        if (tokenState.hasToken)
          const AppChip(
            label: 'Token saved',
            icon: Icons.lock_outline,
            tone: AppChipTone.success,
          )
        else
          TextField(
            key: const Key('onboarding-ai-token-field'),
            controller: tokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Provider token',
              hintText: 'Paste token to save locally',
              helperText: 'You can skip this and add a token later in Me.',
            ),
          ),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.deepGreen : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.warmSurface : AppColors.mutedInk,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? AppColors.warmSurface : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

double _parseNumber(String value, {required double fallback}) {
  return double.tryParse(value.trim()) ?? fallback;
}

double? _parseOptionalNumber(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : double.tryParse(trimmed);
}

List<String> _splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

bool _looksLikeEmail(String email) {
  final trimmed = email.trim();
  return trimmed.contains('@') && trimmed.contains('.');
}
