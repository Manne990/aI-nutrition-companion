import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppMetricData {
  const AppMetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class AppMetricRow extends StatelessWidget {
  const AppMetricRow({super.key, required this.metrics});

  final List<AppMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in metrics) ...[
          Expanded(child: _Metric(metric: metric)),
          if (metric != metrics.last) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.metric});

  final AppMetricData metric;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            metric.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
