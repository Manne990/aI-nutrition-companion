import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/health.dart';
import '../../domain/models/meal_suggestion.dart';
import '../../domain/models/nutrition.dart';
import '../../domain/models/onboarding.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../services/adapters/meal_recognition_adapter.dart';
import '../../services/adapters/nutrition_companion_adapter.dart';
import '../../services/photo/photo_meal_source.dart';
import '../../shared/widgets/ai_message_bubble.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_metric_row.dart';
import '../../shared/widgets/app_section_card.dart';
import '../../shared/widgets/food_image_card.dart';
import '../../shared/widgets/source_chip.dart';
import '../photo_logging/photo_meal_logging_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.profile,
    this.adapter = const MockNutritionCompanionAdapter(),
    this.repository,
    this.photoMealSource,
    this.mealRecognitionAdapter = const MockMealRecognitionAdapter(),
    this.healthSignals,
    this.now,
  });

  final OnboardingProfile profile;
  final NutritionCompanionAdapter adapter;
  final NutritionRepository? repository;
  final PhotoMealSource? photoMealSource;
  final MealRecognitionAdapter mealRecognitionAdapter;
  final HealthSignalSnapshot? healthSignals;
  final DateTime? now;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late List<MealSuggestion> _suggestions;
  late NutritionRepository _repository;
  final TextEditingController _weightController = TextEditingController();
  int _selectedSuggestionIndex = 0;
  _SuggestionAction _lastAction = _SuggestionAction.none;
  String? _aiChoiceMessage;

  @override
  void initState() {
    super.initState();
    _repository = _createRepository();
    _suggestions = _loadSuggestions();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adapter != widget.adapter ||
        oldWidget.profile != widget.profile ||
        oldWidget.healthSignals != widget.healthSignals) {
      _suggestions = _loadSuggestions();
      _selectedSuggestionIndex = 0;
      _lastAction = _SuggestionAction.none;
      _aiChoiceMessage = null;
    }
    if (oldWidget.repository != widget.repository ||
        oldWidget.profile != widget.profile) {
      _repository = _createRepository();
    }
  }

  NutritionRepository _createRepository() {
    return widget.repository ??
        InMemoryNutritionRepository(
          seedGoal: widget.profile.toNutritionGoal(calories: 2200),
          seedPreferences: widget.profile.toUserPreferences(),
        );
  }

  List<MealSuggestion> _loadSuggestions() {
    return widget.adapter.mealSuggestions(
      preferences: widget.profile.toUserPreferences(),
      healthSignals: widget.healthSignals,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime(2026, 6, 29, 15, 30);
    final summary = _repository.dailySummary(now);
    final suggestion = _activeSuggestion;
    final quickLogSuggestions = _repository.quickLogSuggestions(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(_formatDate(now), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'What should I eat next?',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _dayFocus(_repository.userPreferences()),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppChip(
              label: widget.profile.primaryGoal,
              icon: Icons.flag_outlined,
            ),
            AppChip(
              label: '${widget.profile.proteinGoalGrams.round()}g protein goal',
              icon: Icons.fitness_center,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _TodayRhythmCard(now: now, summary: summary),
        const SizedBox(height: AppSpacing.md),
        _DailyNutritionOverviewCard(
          summary: summary,
          weightController: _weightController,
          onSaveWeight: _saveWeightEntry,
        ),
        const SizedBox(height: AppSpacing.md),
        if (suggestion == null)
          const _EmptySuggestionCard()
        else
          _SuggestionCard(
            suggestion: suggestion,
            action: _lastAction,
            onAccept: _acceptSuggestion,
            onRefresh: _refreshSuggestion,
            onDefer: _deferSuggestion,
          ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: 'Daily rhythm',
          child: Text(
            _dailyRhythmCopy(summary),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PhotoMealLoggingCard(
          repository: _repository,
          photoSource: widget.photoMealSource,
          recognitionAdapter: widget.mealRecognitionAdapter,
          now: now,
          onMealSaved: (_) => setState(() {
            _aiChoiceMessage = 'Meal saved. Today totals were updated.';
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        _QuickLogCard(
          suggestions: quickLogSuggestions,
          onConfirm: (quickLogSuggestion) =>
              _confirmQuickLog(quickLogSuggestion, now),
        ),
        const SizedBox(height: AppSpacing.md),
        AiMessageBubble(
          message: _aiInsight(summary, suggestion),
          actions: [
            AiChoiceChip(
              label: 'Show options',
              primary: true,
              onPressed: _suggestions.length > 1 ? _refreshSuggestion : null,
            ),
            AiChoiceChip(
              label: 'Explain why',
              onPressed: suggestion == null
                  ? null
                  : () {
                      setState(() {
                        _aiChoiceMessage =
                            'Because ${suggestion.nutritionRationale.toLowerCase()} and ${suggestion.ingredientAvailability.toLowerCase()}.';
                      });
                    },
            ),
          ],
        ),
        if (_aiChoiceMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppChip(
            label: _aiChoiceMessage!,
            icon: Icons.psychology_alt_outlined,
            tone: AppChipTone.success,
          ),
        ],
      ],
    );
  }

  MealSuggestion? get _activeSuggestion {
    if (_suggestions.isEmpty) {
      return null;
    }
    return _suggestions[_selectedSuggestionIndex % _suggestions.length];
  }

  void _acceptSuggestion() {
    setState(() {
      _lastAction = _SuggestionAction.accepted;
      _aiChoiceMessage = null;
    });
  }

  void _refreshSuggestion() {
    if (_suggestions.length <= 1) {
      return;
    }
    setState(() {
      _selectedSuggestionIndex =
          (_selectedSuggestionIndex + 1) % _suggestions.length;
      _lastAction = _SuggestionAction.changed;
      _aiChoiceMessage = null;
    });
  }

  void _deferSuggestion() {
    setState(() {
      _lastAction = _SuggestionAction.deferred;
      _aiChoiceMessage = null;
    });
  }

  void _saveWeightEntry() {
    final normalized = _weightController.text.trim().replaceAll(',', '.');
    final weightKg = double.tryParse(normalized);
    if (weightKg == null || weightKg <= 0) {
      setState(() {
        _aiChoiceMessage = 'Enter a valid weight in kg.';
      });
      return;
    }

    final now = widget.now ?? DateTime(2026, 6, 29, 15, 30);
    _repository.saveWeightEntry(
      WeightEntry(
        id: 'weight-${now.millisecondsSinceEpoch}',
        recordedAt: now,
        weightKg: weightKg,
        source: NutritionSeedData.userSource,
      ),
    );
    setState(() {
      _weightController.clear();
      _aiChoiceMessage = 'Weight saved. Trend updated for today.';
    });
  }

  void _confirmQuickLog(QuickLogSuggestion suggestion, DateTime now) {
    _repository.confirmQuickLogSuggestion(suggestion, eatenAt: now);
    setState(() {
      _aiChoiceMessage = '${suggestion.mealName} added from Quick Log.';
    });
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.action,
    required this.onAccept,
    required this.onRefresh,
    required this.onDefer,
  });

  final MealSuggestion suggestion;
  final _SuggestionAction action;
  final VoidCallback onAccept;
  final VoidCallback onRefresh;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImageCard(
              icon: _imageIcon,
              semanticLabel: '${suggestion.title} suggestion image placeholder',
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppChip(
              label: 'Suggested next',
              icon: Icons.auto_awesome,
              tone: AppChipTone.accent,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(suggestion.summary),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppChip(
                  label: '${suggestion.prepMinutes} min prep',
                  icon: Icons.timer_outlined,
                ),
                AppChip(
                  label: suggestion.ingredientAvailability,
                  icon: Icons.kitchen_outlined,
                  tone: AppChipTone.success,
                ),
                AppChip(
                  label: suggestion.nutritionRationale,
                  icon: Icons.insights_outlined,
                  tone: AppChipTone.accent,
                ),
                AppChip(label: '${suggestion.proteinGrams}g protein'),
                AppChip(label: '${suggestion.calories} kcal'),
                SourceChip(source: suggestion.source),
              ],
            ),
            if (action != _SuggestionAction.none) ...[
              const SizedBox(height: AppSpacing.md),
              AppChip(
                label: _actionLabel(action, suggestion),
                icon: _actionIcon(action),
                tone: AppChipTone.success,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: 'Accept suggestion',
                    icon: Icons.check_circle_outline,
                    onPressed: onAccept,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Change',
                        icon: Icons.refresh,
                        onPressed: onRefresh,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Not now',
                        icon: Icons.schedule_outlined,
                        onPressed: onDefer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData get _imageIcon {
    return switch (suggestion.imageAssetKey) {
      'fixture-chicken-wrap' => Icons.lunch_dining,
      'fixture-smoothie' => Icons.local_drink_outlined,
      _ => Icons.ramen_dining,
    };
  }
}

class _TodayRhythmCard extends StatelessWidget {
  const _TodayRhythmCard({required this.now, required this.summary});

  final DateTime now;
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Today rhythm',
      child: AppMetricRow(
        metrics: [
          AppMetricData(label: 'Current moment', value: _currentMoment(now)),
          AppMetricData(
            label: 'Last meal',
            value: _lastMealLabel(now, summary),
          ),
          AppMetricData(label: 'Protein gap', value: _proteinGapLabel(summary)),
        ],
      ),
    );
  }
}

class _DailyNutritionOverviewCard extends StatelessWidget {
  const _DailyNutritionOverviewCard({
    required this.summary,
    required this.weightController,
    required this.onSaveWeight,
  });

  final DailySummary summary;
  final TextEditingController weightController;
  final VoidCallback onSaveWeight;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Daily overview',
      eyebrow: 'Progress today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppChip(
                label: _sourceStateLabel(summary),
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ProteinProgress(summary: summary),
          const SizedBox(height: AppSpacing.md),
          AppMetricRow(
            metrics: [
              AppMetricData(
                label: 'Calories',
                value: _macroGoalLabel(
                  summary.knownMacroTotals.calories,
                  summary.goal?.calories,
                  'kcal',
                ),
              ),
              AppMetricData(
                label: 'Carbs',
                value: _macroGoalLabel(
                  summary.knownMacroTotals.carbsGrams,
                  summary.goal?.carbsGrams,
                  'g',
                ),
              ),
              AppMetricData(
                label: 'Fat',
                value: _macroGoalLabel(
                  summary.knownMacroTotals.fatGrams,
                  summary.goal?.fatGrams,
                  'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DecisionSupport(summary: summary),
          const SizedBox(height: AppSpacing.md),
          _MealHistory(summary: summary),
          const SizedBox(height: AppSpacing.md),
          _WeightTracker(
            controller: weightController,
            summary: summary,
            onSave: onSaveWeight,
          ),
        ],
      ),
    );
  }
}

class _ProteinProgress extends StatelessWidget {
  const _ProteinProgress({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.proteinProgress ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Protein',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              _macroGoalLabel(
                summary.knownMacroTotals.proteinGrams,
                summary.goal?.proteinGrams,
                'g',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          backgroundColor: AppColors.oat,
          color: progress >= 1 ? AppColors.leafGreen : AppColors.peachInk,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _proteinProgressCopy(summary),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
        ),
      ],
    );
  }
}

class _DecisionSupport extends StatelessWidget {
  const _DecisionSupport({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights_outlined, color: AppColors.deepGreen),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _nextStepInsight(summary),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealHistory extends StatelessWidget {
  const _MealHistory({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.meals.isEmpty) {
      return const Text(
        'Meal history is empty for today. Log a meal to turn the overview into live decision support.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final meal in summary.meals) ...[
          _MealHistoryRow(meal: meal),
          if (meal != summary.meals.last) const Divider(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _MealHistoryRow extends StatelessWidget {
  const _MealHistoryRow({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final macros = meal.knownMacroTotals;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            _formatTime(meal.eatenAt),
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${macros.calories.round()} kcal | ${macros.proteinGrams.round()}g protein',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
              ),
              if (meal.hasMissingNutrition) ...[
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Includes an item that still needs confirmation.',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightTracker extends StatelessWidget {
  const _WeightTracker({
    required this.controller,
    required this.summary,
    required this.onSave,
  });

  final TextEditingController controller;
  final DailySummary summary;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestWeightEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weight trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          latest == null
              ? 'No weight entry yet.'
              : '${latest.weightKg.toStringAsFixed(1)} kg | ${_weightTrendLabel(summary)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Add weight',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickLogCard extends StatelessWidget {
  const _QuickLogCard({required this.suggestions, required this.onConfirm});

  final List<QuickLogSuggestion> suggestions;
  final ValueChanged<QuickLogSuggestion> onConfirm;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const AppSectionCard(
        title: 'Quick Log',
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.warmSurface,
        trailing: AppChip(
          label: 'Learning',
          tone: AppChipTone.inverse,
          icon: Icons.auto_graph,
        ),
        child: Text(
          'Log a few meals and common snacks will appear here for one-tap confirmation.',
          style: TextStyle(color: AppColors.warmSurface),
        ),
      );
    }

    return AppSectionCard(
      title: 'Quick Log',
      backgroundColor: AppColors.deepGreen,
      foregroundColor: AppColors.warmSurface,
      trailing: const AppChip(
        label: 'Habit detected',
        tone: AppChipTone.inverse,
        icon: Icons.auto_graph,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${suggestions.first.timeWindowLabel} suggestions from your meal rhythm.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.warmSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final suggestion in suggestions) ...[
            _QuickLogSuggestionRow(
              suggestion: suggestion,
              onConfirm: () => onConfirm(suggestion),
            ),
            if (suggestion != suggestions.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _QuickLogSuggestionRow extends StatelessWidget {
  const _QuickLogSuggestionRow({
    required this.suggestion,
    required this.onConfirm,
  });

  final QuickLogSuggestion suggestion;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final macros = suggestion.macroTotals;
    final macroLabel = macros == null
        ? 'Nutrition pending'
        : '${macros.calories.round()} kcal | ${macros.proteinGrams.round()}g protein';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warmSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.mealName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.warmSurface),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${suggestion.reason}. $macroLabel.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.warmSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonalIcon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Log'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppChip(
                  label: _availabilityLabel(suggestion.availability),
                  tone: AppChipTone.inverse,
                  icon: Icons.kitchen_outlined,
                ),
                AppChip(
                  label: suggestion.source.label ?? 'Habit suggestion',
                  tone: AppChipTone.inverse,
                  icon: Icons.auto_awesome,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySuggestionCard extends StatelessWidget {
  const _EmptySuggestionCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      title: 'No meal suggestion ready',
      eyebrow: 'Suggested next',
      child: Text(
        'Log a meal or add preferences and the companion will suggest what to eat next. Today still works without fixture suggestion data.',
      ),
    );
  }
}

enum _SuggestionAction { none, accepted, changed, deferred }

String _formatDate(DateTime date) {
  return '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
}

String _dayFocus(UserPreferences preferences) {
  return 'Today focus: ${preferences.primaryGoal}.';
}

String _dailyRhythmCopy(DailySummary summary) {
  if (summary.meals.isEmpty) {
    return 'No meals logged yet today. The first useful step is a low-friction breakfast, snack, or photo log.';
  }
  final mealNames = summary.meals.map((meal) => meal.name).join(', ');
  final missingCopy = summary.hasMissingNutrition
      ? ' Some nutrition is still estimated.'
      : '';
  return 'Logged today: $mealNames.$missingCopy Use the next meal to keep the day balanced.';
}

String _aiInsight(DailySummary summary, MealSuggestion? suggestion) {
  final remaining = summary.proteinRemainingGrams;
  if (suggestion == null) {
    return 'I do not have a suggestion yet, but I can still help you choose once you add a meal, preference, or quick log item.';
  }
  if (remaining == null) {
    return '${suggestion.title} fits your current rhythm and keeps the next step simple.';
  }
  return 'You are about ${remaining.round()}g short of protein today. ${suggestion.title} helps without making dinner feel locked in.';
}

String _sourceStateLabel(DailySummary summary) {
  if (summary.meals.isEmpty) {
    return 'No sources yet';
  }
  if (summary.hasMissingNutrition) {
    return 'Needs confirmation';
  }
  final hasEstimates = summary.meals
      .expand((meal) => meal.items)
      .any(
        (item) =>
            item.source.source == NutritionSource.aiEstimated ||
            item.source.source == NutritionSource.fallback ||
            item.food.source.source == NutritionSource.aiEstimated ||
            item.food.source.source == NutritionSource.fallback,
      );
  return hasEstimates ? 'Mixed sources' : 'Confirmed data';
}

String _macroGoalLabel(double current, double? goal, String unit) {
  final currentLabel = current.round();
  if (goal == null) {
    return '$currentLabel $unit';
  }
  return '$currentLabel / ${goal.round()} $unit';
}

String _proteinProgressCopy(DailySummary summary) {
  final remaining = summary.proteinRemainingGrams;
  if (remaining == null) {
    return 'Set a protein goal to make this progress actionable.';
  }
  if (remaining == 0) {
    return 'Protein goal met. Keep the next meal comfortable and balanced.';
  }
  return '${remaining.round()}g protein left. Prioritize a simple protein anchor next.';
}

String _nextStepInsight(DailySummary summary) {
  if (summary.meals.isEmpty) {
    return 'Start with any easy meal or photo log so the companion has a real baseline for the day.';
  }
  if (summary.hasMissingNutrition) {
    return 'Confirm the estimated item when you can; the protein signal is useful, but the calorie total may move.';
  }
  if (summary.proteinRemainingGrams == 0) {
    return 'Your protein target is covered. Choose the next meal for energy, comfort, and consistency.';
  }
  return 'Use the next eating moment to close the protein gap without forcing a full meal.';
}

String _weightTrendLabel(DailySummary summary) {
  final delta = summary.weightDeltaKg;
  if (delta == null) {
    return 'First local entry';
  }
  if (delta == 0) {
    return 'No change';
  }
  final direction = delta > 0 ? 'Up' : 'Down';
  return '$direction ${delta.abs().toStringAsFixed(1)} kg';
}

String _availabilityLabel(IngredientAvailability availability) {
  return switch (availability) {
    IngredientAvailability.available => 'Available',
    IngredientAvailability.runningLow => 'Check quantity',
    IngredientAvailability.missing => 'Missing',
    IngredientAvailability.unknown => 'Availability unknown',
  };
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _currentMoment(DateTime now) {
  final hour = now.hour;
  if (hour < 11) {
    return 'Morning';
  }
  if (hour < 15) {
    return 'Midday';
  }
  if (hour < 18) {
    return 'Afternoon';
  }
  return 'Evening';
}

String _lastMealLabel(DateTime now, DailySummary summary) {
  if (summary.meals.isEmpty) {
    return 'No meals yet';
  }
  final lastMeal = summary.meals.last;
  final elapsed = now.difference(lastMeal.eatenAt);
  if (elapsed.isNegative) {
    return lastMeal.name;
  }
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  if (hours == 0) {
    return '${minutes}m ago';
  }
  return '${hours}h ${minutes}m ago';
}

String _proteinGapLabel(DailySummary summary) {
  final remaining = summary.proteinRemainingGrams;
  if (remaining == null) {
    return 'Goal not set';
  }
  if (remaining == 0) {
    return 'Goal met';
  }
  return '${remaining.round()}g left';
}

String _actionLabel(_SuggestionAction action, MealSuggestion suggestion) {
  return switch (action) {
    _SuggestionAction.none => '',
    _SuggestionAction.accepted => 'Accepted ${suggestion.title}',
    _SuggestionAction.changed => 'Changed to ${suggestion.title}',
    _SuggestionAction.deferred => 'Deferred for later',
  };
}

IconData _actionIcon(_SuggestionAction action) {
  return switch (action) {
    _SuggestionAction.none => Icons.info_outline,
    _SuggestionAction.accepted => Icons.check_circle_outline,
    _SuggestionAction.changed => Icons.refresh,
    _SuggestionAction.deferred => Icons.schedule_outlined,
  };
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
