import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
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

class NutritionSourceDetailsButton extends StatelessWidget {
  const NutritionSourceDetailsButton({
    super.key,
    required this.metadata,
    this.title = 'Nutrition source',
  });

  final SourceMetadata metadata;
  final String title;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showSourceDetails(context),
      icon: const Icon(Icons.info_outline, size: 18),
      label: const Text('Source details'),
    );
  }

  void _showSourceDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: NutritionSourceDetails(metadata: metadata, title: title),
            ),
          ),
        );
      },
    );
  }
}

class NutritionSourceDetails extends StatelessWidget {
  const NutritionSourceDetails({
    super.key,
    required this.metadata,
    this.title = 'Nutrition source',
  });

  final SourceMetadata metadata;
  final String title;

  @override
  Widget build(BuildContext context) {
    final provider = metadata.provider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition source details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        _SourceDetailRow(
          label: 'Source label',
          value: nutritionSourceLabel(metadata),
        ),
        _SourceDetailRow(
          label: 'Lookup mode',
          value: nutritionSourceModeLabel(metadata.source),
        ),
        _SourceDetailRow(
          label: 'Provider',
          value: provider == null || provider.isEmpty
              ? 'Not recorded'
              : _providerLabel(provider),
        ),
        _SourceDetailRow(
          label: 'Provider id',
          value: provider == null || provider.isEmpty
              ? 'Not recorded'
              : provider,
        ),
        _SourceDetailRow(
          label: 'Observed time',
          value: _observedAtLabel(metadata.observedAt),
        ),
        _SourceDetailRow(
          label: 'Confidence',
          value: metadata.confidence == null
              ? 'Not recorded'
              : '${(_clampConfidence(metadata.confidence!) * 100).round()}%',
        ),
        _SourceDetailRow(
          label: 'Database verified',
          value: metadata.source == NutritionSource.databaseVerified
              ? 'Yes'
              : 'No',
        ),
        _SourceDetailRow(
          label: 'User confirmed',
          value: metadata.source == NutritionSource.userConfirmed
              ? 'Yes'
              : 'No',
        ),
        if (metadata.source == NutritionSource.fallback)
          _SourceDetailRow(
            label: 'Fallback reason',
            value: metadata.label == null || metadata.label!.isEmpty
                ? 'Fallback source did not record a reason.'
                : metadata.label!,
          ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

class _SourceDetailRow extends StatelessWidget {
  const _SourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
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

String nutritionSourceModeLabel(NutritionSource source) {
  return switch (source) {
    NutritionSource.aiEstimated => 'AI estimate',
    NutritionSource.userConfirmed => 'User confirmation',
    NutritionSource.databaseVerified => 'Database verified',
    NutritionSource.fallback => 'Fallback/local',
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

String _observedAtLabel(DateTime? observedAt) {
  if (observedAt == null) {
    return 'Not recorded';
  }
  final local = observedAt.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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
