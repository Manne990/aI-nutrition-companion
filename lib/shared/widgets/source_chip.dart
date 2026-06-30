import 'package:flutter/material.dart';

import '../../domain/models/nutrition.dart';
import 'app_chip.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source, this.metadata});

  SourceChip.fromMetadata({super.key, required SourceMetadata metadata})
    : source = metadata.source,
      metadata = metadata;

  final NutritionSource source;
  final SourceMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: nutritionSourceLabel(metadata ?? SourceMetadata(source: source)),
      icon: _icon,
      tone: _tone,
    );
  }

  AppChipTone get _tone {
    return switch (source) {
      NutritionSource.databaseVerified => AppChipTone.success,
      NutritionSource.userConfirmed => AppChipTone.success,
      NutritionSource.aiEstimated => AppChipTone.accent,
      NutritionSource.fallback => AppChipTone.accent,
    };
  }

  IconData get _icon {
    return switch (source) {
      NutritionSource.databaseVerified => Icons.verified_outlined,
      NutritionSource.userConfirmed => Icons.check_circle_outline,
      NutritionSource.aiEstimated => Icons.auto_awesome,
      NutritionSource.fallback => Icons.info_outline,
    };
  }
}

String nutritionSourceLabel(SourceMetadata metadata) {
  final provider = metadata.provider;
  if (provider != null && provider.isNotEmpty) {
    final providerLabel = _providerLabel(provider);
    if (metadata.source == NutritionSource.fallback) {
      if (providerLabel.toLowerCase().contains('fallback')) {
        return providerLabel;
      }
      return '$providerLabel fallback';
    }
    if (metadata.source == NutritionSource.aiEstimated &&
        providerLabel != 'AI estimate') {
      return providerLabel;
    }
    return providerLabel;
  }

  final label = metadata.label;
  if (label != null && label.isNotEmpty) {
    return label;
  }

  return switch (metadata.source) {
    NutritionSource.aiEstimated => 'AI-estimated',
    NutritionSource.userConfirmed => 'User-confirmed',
    NutritionSource.databaseVerified => 'Database-verified',
    NutritionSource.fallback => 'Fallback data',
  };
}

String nutritionSourceDetail(SourceMetadata metadata) {
  final label = nutritionSourceLabel(metadata);
  final confidence = metadata.confidence;
  final confidenceCopy = confidence == null
      ? ''
      : ' Confidence ${(_clampConfidence(confidence) * 100).round()}%.';

  return switch (metadata.source) {
    NutritionSource.databaseVerified =>
      '$label nutrition source.$confidenceCopy',
    NutritionSource.userConfirmed =>
      '$label values saved from your confirmation.',
    NutritionSource.aiEstimated =>
      '$label nutrition estimate; confirm before relying on exact totals.$confidenceCopy',
    NutritionSource.fallback =>
      '$label values are a fallback for practical planning; confirm if precision matters.',
  };
}

String _providerLabel(String provider) {
  return switch (provider) {
    'open-food-facts' => 'Open Food Facts',
    'fooddata-central' => 'FoodData Central',
    'local-fallback' => 'Local fallback',
    'local-seed' => 'Local nutrition data',
    'local-history' => 'Local history',
    'mock-ai' => 'AI estimate',
    'mock-photo-ai' => 'Photo AI estimate',
    _ =>
      provider
          .split(RegExp('[-_]+'))
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' '),
  };
}

double _clampConfidence(double value) {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}
