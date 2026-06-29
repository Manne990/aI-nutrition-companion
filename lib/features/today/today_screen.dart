import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
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
    this.now,
  });

  final OnboardingProfile profile;
  final NutritionCompanionAdapter adapter;
  final NutritionRepository? repository;
  final PhotoMealSource? photoMealSource;
  final MealRecognitionAdapter mealRecognitionAdapter;
  final DateTime? now;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late List<MealSuggestion> _suggestions;
  late NutritionRepository _repository;
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
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adapter != widget.adapter ||
        oldWidget.profile != widget.profile) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime(2026, 6, 29, 15, 30);
    final summary = _repository.dailySummary(now);
    final suggestion = _activeSuggestion;

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
        const AppSectionCard(
          title: 'Quick Log',
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.warmSurface,
          trailing: AppChip(label: 'Habit detected', tone: AppChipTone.inverse),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppChip(label: 'Greek yogurt', tone: AppChipTone.inverse),
              AppChip(label: 'Chicken salad', tone: AppChipTone.inverse),
              AppChip(label: 'Banana', tone: AppChipTone.inverse),
            ],
          ),
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
