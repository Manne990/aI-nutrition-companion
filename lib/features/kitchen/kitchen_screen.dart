import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_section_card.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key, this.repository});

  final NutritionRepository? repository;

  @override
  Widget build(BuildContext context) {
    final nutritionRepository = repository ?? InMemoryNutritionRepository();
    final favorites = nutritionRepository.favoriteMeals();
    final inventory = nutritionRepository.kitchenInventory();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Kitchen', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Common meals and ingredient availability for faster logging.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Favorite meals',
          child: _FavoriteMealsList(favorites: favorites),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: 'Ingredient availability',
          child: _InventoryList(items: inventory),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSectionCard(
          title: 'Habit suggestions',
          child: Text(
            favorites.isEmpty
                ? 'Log meals and Quick Log will begin suggesting repeated foods by time of day.'
                : 'Quick Log uses these meals plus time-of-day patterns to suggest one-tap entries.',
          ),
        ),
      ],
    );
  }
}

class _FavoriteMealsList extends StatelessWidget {
  const _FavoriteMealsList({required this.favorites});

  final List<KitchenFavoriteMeal> favorites;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Text(
        'Reusable meals will appear here after you log them once.',
      );
    }

    return Column(
      children: [
        for (final favorite in favorites) ...[
          _FavoriteMealRow(favorite: favorite),
          if (favorite != favorites.last) const Divider(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _FavoriteMealRow extends StatelessWidget {
  const _FavoriteMealRow({required this.favorite});

  final KitchenFavoriteMeal favorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.restaurant_outlined, color: AppColors.deepGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                favorite.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                favorite.itemNames.join(', '),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppChip(label: '${favorite.timesLogged}x logged'),
                  AppChip(
                    label:
                        '${favorite.knownMacroTotals.proteinGrams.round()}g protein',
                    tone: AppChipTone.success,
                  ),
                  AppChip(
                    label: '${favorite.knownMacroTotals.calories.round()} kcal',
                    tone: AppChipTone.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.items});

  final List<KitchenInventoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'Ingredients will appear here as the local food list grows.',
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in items)
          AppChip(
            label: '${item.food.name} · ${_availabilityLabel(item)}',
            icon: item.isFavorite ? Icons.star_outline : Icons.kitchen_outlined,
            tone: _availabilityTone(item.availability),
          ),
      ],
    );
  }
}

String _availabilityLabel(KitchenInventoryItem item) {
  return switch (item.availability) {
    IngredientAvailability.available => 'available',
    IngredientAvailability.runningLow => 'check quantity',
    IngredientAvailability.missing => 'missing',
    IngredientAvailability.unknown => 'unknown',
  };
}

AppChipTone _availabilityTone(IngredientAvailability availability) {
  return switch (availability) {
    IngredientAvailability.available => AppChipTone.success,
    IngredientAvailability.runningLow => AppChipTone.accent,
    IngredientAvailability.missing => AppChipTone.neutral,
    IngredientAvailability.unknown => AppChipTone.neutral,
  };
}
