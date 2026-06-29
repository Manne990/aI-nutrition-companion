import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum AppChipTone { neutral, accent, success, inverse }

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final AppChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colors.foreground, size: 16),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ChipColors get _colors {
    return switch (tone) {
      AppChipTone.neutral => const _ChipColors(
        background: AppColors.warmSurface,
        foreground: AppColors.mutedInk,
        border: AppColors.oat,
      ),
      AppChipTone.accent => _ChipColors(
        background: AppColors.peach.withValues(alpha: 0.24),
        foreground: AppColors.peachInk,
        border: AppColors.peach.withValues(alpha: 0.34),
      ),
      AppChipTone.success => _ChipColors(
        background: AppColors.leafGreen.withValues(alpha: 0.12),
        foreground: AppColors.deepGreen,
        border: AppColors.leafGreen.withValues(alpha: 0.16),
      ),
      AppChipTone.inverse => _ChipColors(
        background: Colors.white.withValues(alpha: 0.12),
        foreground: AppColors.warmSurface,
        border: Colors.white.withValues(alpha: 0.18),
      ),
    };
  }
}

class _ChipColors {
  const _ChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
