import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class FoodImageCard extends StatelessWidget {
  const FoodImageCard({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.height = 156,
  });

  final IconData icon;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.peach, AppColors.deepGreen],
          ),
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warmSurface.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Icon(icon, color: AppColors.deepGreen, size: 58),
            ),
          ),
        ),
      ),
    );
  }
}
