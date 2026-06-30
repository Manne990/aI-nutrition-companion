import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../services/adapters/meal_recognition_adapter.dart';
import '../../services/photo/photo_meal_source.dart';
import '../../shared/widgets/app_action_buttons.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_metric_row.dart';
import '../../shared/widgets/app_section_card.dart';
import '../../shared/widgets/source_chip.dart';

class PhotoMealLoggingCard extends StatefulWidget {
  const PhotoMealLoggingCard({
    super.key,
    required this.repository,
    this.photoSource,
    this.recognitionAdapter = const MockMealRecognitionAdapter(),
    this.now,
    this.onMealSaved,
  });

  final NutritionRepository repository;
  final PhotoMealSource? photoSource;
  final MealRecognitionAdapter recognitionAdapter;
  final DateTime? now;
  final ValueChanged<Meal>? onMealSaved;

  @override
  State<PhotoMealLoggingCard> createState() => _PhotoMealLoggingCardState();
}

class _PhotoMealLoggingCardState extends State<PhotoMealLoggingCard> {
  late final PhotoMealSource _photoSource;
  MealEstimate? _estimate;
  Meal? _savedMeal;
  String? _statusMessage;
  String? _errorMessage;
  var _isWorking = false;
  var _drafts = <_EditableMealItem>[];

  @override
  void initState() {
    super.initState();
    _photoSource = widget.photoSource ?? ImagePickerPhotoMealSource();
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Photo meal log',
      eyebrow: 'Fast capture',
      trailing: const AppChip(label: 'Mock AI', icon: Icons.auto_awesome),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Take or choose a meal photo, review the estimate, correct it, then save confirmed values.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Take photo',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _isWorking
                      ? null
                      : () => _start(PhotoMealCaptureMode.camera),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppSecondaryButton(
                  label: 'Choose photo',
                  icon: Icons.photo_library_outlined,
                  onPressed: _isWorking
                      ? null
                      : () => _start(PhotoMealCaptureMode.gallery),
                ),
              ),
            ],
          ),
          if (_isWorking) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppChip(
              label: _statusMessage!,
              icon: Icons.info_outline,
              tone: AppChipTone.success,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppChip(
              label: _errorMessage!,
              icon: Icons.error_outline,
              tone: AppChipTone.accent,
            ),
          ],
          if (_estimate != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _EstimateReview(
              estimate: _estimate!,
              drafts: _drafts,
              totals: _totals,
              onDraftChanged: _updateDraft,
              onRemove: _removeDraft,
              onAdd: _addDraft,
              onSave: _activeDrafts.isEmpty ? null : _saveMeal,
            ),
          ],
          if (_savedMeal != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppChip(
              label:
                  'Saved ${_savedMeal!.name} with ${_savedMeal!.items.length} confirmed items',
              icon: Icons.check_circle_outline,
              tone: AppChipTone.success,
            ),
          ],
        ],
      ),
    );
  }

  Iterable<_EditableMealItem> get _activeDrafts {
    return _drafts.where((draft) => !draft.isRemoved);
  }

  MacroTotals get _totals {
    return _activeDrafts.fold(
      const MacroTotals.zero(),
      (total, draft) => total + draft.macroTotals,
    );
  }

  Future<void> _start(PhotoMealCaptureMode mode) async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
      _statusMessage = null;
      _savedMeal = null;
    });

    try {
      final capture = await _photoSource.pickPhoto(mode);
      if (!mounted) {
        return;
      }
      if (capture == null) {
        setState(() {
          _isWorking = false;
          _statusMessage = 'Photo selection cancelled. Nothing was saved.';
        });
        return;
      }

      final estimate = await widget.recognitionAdapter.estimateMealFromPhoto(
        capture,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _estimate = estimate;
        _drafts = estimate.items.map(_EditableMealItem.fromMealItem).toList();
        _isWorking = false;
        _statusMessage =
            'AI estimate ready. Values stay estimated until you confirm them.';
      });
    } on PhotoMealCaptureException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
        _errorMessage = error.message;
      });
    } on MealRecognitionException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
        _errorMessage = error.message;
      });
    }
  }

  void _updateDraft(_EditableMealItem draft) {
    setState(() {
      _drafts = [
        for (final existing in _drafts)
          if (existing.id == draft.id) draft else existing,
      ];
      _savedMeal = null;
    });
  }

  void _removeDraft(_EditableMealItem draft) {
    _updateDraft(draft.copyWith(isRemoved: true));
  }

  void _addDraft() {
    final nextIndex = _drafts.length + 1;
    setState(() {
      _drafts = [
        ..._drafts,
        _EditableMealItem(
          id: 'manual-$nextIndex',
          originalItemId: null,
          name: 'Added food',
          servingDescription: '1 serving',
          servings: 1,
          calories: 100,
          proteinGrams: 10,
          carbsGrams: 8,
          fatGrams: 4,
          source: const SourceMetadata(
            source: NutritionSource.userConfirmed,
            label: 'User added',
          ),
        ),
      ];
      _savedMeal = null;
    });
  }

  void _saveMeal() {
    final estimate = _estimate;
    if (estimate == null) {
      return;
    }

    final savedAt = widget.now ?? DateTime(2026, 6, 29, 17, 50);
    final correctedItems = _activeDrafts.map((draft) {
      final food = FoodItem(
        id: 'confirmed-food-${draft.id}',
        name: draft.name.trim().isEmpty ? 'Corrected food' : draft.name.trim(),
        servingDescription: draft.servingDescription.trim().isEmpty
            ? 'Corrected serving'
            : draft.servingDescription.trim(),
        nutritionPerServing: MacroTotals(
          calories: draft.calories,
          proteinGrams: draft.proteinGrams,
          carbsGrams: draft.carbsGrams,
          fatGrams: draft.fatGrams,
        ),
        source: draft.source,
      );
      return MealItem(
        id: 'confirmed-${draft.id}',
        food: food,
        servings: draft.servings,
        source: const SourceMetadata(
          source: NutritionSource.userConfirmed,
          label: 'User confirmed from photo',
        ),
        replacesEstimateId: draft.originalItemId,
      );
    }).toList();

    final meal = estimate.confirm(
      mealId: 'photo-meal-${savedAt.millisecondsSinceEpoch}',
      name: 'Photo meal',
      eatenAt: savedAt,
      correctedItems: correctedItems,
    );
    widget.repository.saveMeal(meal);
    widget.onMealSaved?.call(meal);
    setState(() {
      _savedMeal = meal;
      _statusMessage = 'Confirmed values saved to today.';
      _errorMessage = null;
    });
  }
}

class _EstimateReview extends StatelessWidget {
  const _EstimateReview({
    required this.estimate,
    required this.drafts,
    required this.totals,
    required this.onDraftChanged,
    required this.onRemove,
    required this.onAdd,
    required this.onSave,
  });

  final MealEstimate estimate;
  final List<_EditableMealItem> drafts;
  final MacroTotals totals;
  final ValueChanged<_EditableMealItem> onDraftChanged;
  final ValueChanged<_EditableMealItem> onRemove;
  final VoidCallback onAdd;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final activeDrafts = drafts.where((draft) => !draft.isRemoved).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Review estimate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SourceChip.fromMetadata(metadata: estimate.source),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Estimated confidence ${((estimate.source.confidence ?? 0) * 100).round()}%. Edit before saving confirmed values.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: AppSpacing.md),
        AppMetricRow(
          metrics: [
            AppMetricData(
              label: 'Calories',
              value: totals.calories.round().toString(),
            ),
            AppMetricData(
              label: 'Protein',
              value: '${totals.proteinGrams.round()}g',
            ),
            AppMetricData(
              label: 'Carbs',
              value: '${totals.carbsGrams.round()}g',
            ),
            AppMetricData(label: 'Fat', value: '${totals.fatGrams.round()}g'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final draft in activeDrafts) ...[
          _EditableMealItemFields(
            draft: draft,
            onChanged: onDraftChanged,
            onRemove: onRemove,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Add item',
                icon: Icons.add_circle_outline,
                onPressed: onAdd,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppPrimaryButton(
                label: 'Save confirmed meal',
                icon: Icons.check_circle_outline,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditableMealItemFields extends StatelessWidget {
  const _EditableMealItemFields({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableMealItem draft;
  final ValueChanged<_EditableMealItem> onChanged;
  final ValueChanged<_EditableMealItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.oat),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SourceChip.fromMetadata(metadata: draft.source),
                ),
                IconButton(
                  tooltip: 'Remove ${draft.name}',
                  onPressed: () => onRemove(draft),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('photo-meal-name-${draft.id}'),
              initialValue: draft.name,
              decoration: const InputDecoration(labelText: 'Food name'),
              textInputAction: TextInputAction.next,
              onChanged: (value) => onChanged(draft.copyWith(name: value)),
            ),
            TextFormField(
              key: ValueKey('photo-meal-serving-${draft.id}'),
              initialValue: draft.servingDescription,
              decoration: const InputDecoration(labelText: 'Portion'),
              textInputAction: TextInputAction.next,
              onChanged: (value) =>
                  onChanged(draft.copyWith(servingDescription: value)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    key: ValueKey('photo-meal-servings-${draft.id}'),
                    label: 'Servings',
                    value: draft.servings,
                    onChanged: (value) =>
                        onChanged(draft.copyWith(servings: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _NumberField(
                    key: ValueKey('photo-meal-calories-${draft.id}'),
                    label: 'kcal',
                    value: draft.calories,
                    onChanged: (value) =>
                        onChanged(draft.copyWith(calories: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    key: ValueKey('photo-meal-protein-${draft.id}'),
                    label: 'Protein g',
                    value: draft.proteinGrams,
                    onChanged: (value) =>
                        onChanged(draft.copyWith(proteinGrams: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _NumberField(
                    key: ValueKey('photo-meal-carbs-${draft.id}'),
                    label: 'Carbs g',
                    value: draft.carbsGrams,
                    onChanged: (value) =>
                        onChanged(draft.copyWith(carbsGrams: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _NumberField(
                    key: ValueKey('photo-meal-fat-${draft.id}'),
                    label: 'Fat g',
                    value: draft.fatGrams,
                    onChanged: (value) =>
                        onChanged(draft.copyWith(fatGrams: value)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: _numberLabel(value),
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null && parsed >= 0) {
          onChanged(parsed);
        }
      },
    );
  }
}

class _EditableMealItem {
  const _EditableMealItem({
    required this.id,
    required this.originalItemId,
    required this.name,
    required this.servingDescription,
    required this.servings,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.source,
    this.isRemoved = false,
  });

  factory _EditableMealItem.fromMealItem(MealItem item) {
    final totals = item.food.nutritionPerServing ?? const MacroTotals.zero();
    return _EditableMealItem(
      id: item.id,
      originalItemId: item.id,
      name: item.food.name,
      servingDescription: item.food.servingDescription,
      servings: item.servings,
      calories: totals.calories,
      proteinGrams: totals.proteinGrams,
      carbsGrams: totals.carbsGrams,
      fatGrams: totals.fatGrams,
      source: item.source,
    );
  }

  final String id;
  final String? originalItemId;
  final String name;
  final String servingDescription;
  final double servings;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final SourceMetadata source;
  final bool isRemoved;

  MacroTotals get macroTotals {
    return MacroTotals(
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    ).scale(servings);
  }

  _EditableMealItem copyWith({
    String? name,
    String? servingDescription,
    double? servings,
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    bool? isRemoved,
  }) {
    return _EditableMealItem(
      id: id,
      originalItemId: originalItemId,
      name: name ?? this.name,
      servingDescription: servingDescription ?? this.servingDescription,
      servings: servings ?? this.servings,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      source: source,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}

String _numberLabel(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
