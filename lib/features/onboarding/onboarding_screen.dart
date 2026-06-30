import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/nutrition.dart';
import '../../domain/models/onboarding.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_section_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final ValueChanged<OnboardingProfile> onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _allergyController = TextEditingController();
  final _dislikedController = TextEditingController();
  final _proteinController = TextEditingController(text: '110');
  final _targetWeightController = TextEditingController();

  int _step = 0;
  String _primaryGoal = 'Build steady high-protein habits';
  String _coachingTone = 'calm and practical';
  bool _acceptedNutrition = false;
  bool _acceptedAi = false;
  bool _acceptedPrivacy = false;
  LocalDataBackupPreference _backupPreference =
      LocalDataBackupPreference.localOnly;
  bool _healthConnectionApproved = false;
  final Set<String> _dietaryPreferences = {'high protein'};

  bool get _canFinish => _acceptedNutrition && _acceptedAi && _acceptedPrivacy;

  @override
  void dispose() {
    _controller.dispose();
    _allergyController.dispose();
    _dislikedController.dispose();
    _proteinController.dispose();
    _targetWeightController.dispose();
    super.dispose();
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
                    '${_step + 1} / 4',
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
                  if (_step == 1 || _step == 2) ...[
                    AppSecondaryButton(label: 'Skip', onPressed: _goNext),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: _step == 3 ? 'Start Today' : 'Continue',
                      onPressed: _step == 3 && !_canFinish
                          ? null
                          : (_step == 3 ? _complete : _goNext),
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
    final nextStep = (_step - 1).clamp(0, 3);
    _controller.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    final nextStep = (_step + 1).clamp(0, 3);
    _controller.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _complete() {
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
