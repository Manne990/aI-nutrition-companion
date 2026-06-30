import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return FilledButton(onPressed: onPressed, child: child);
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class AppActionButtonGroup extends StatelessWidget {
  const AppActionButtonGroup({
    super.key,
    required this.children,
    this.stackedBreakpoint = 360,
  });

  final List<Widget> children;
  final double stackedBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth <= stackedBreakpoint;
        final spacedChildren = <Widget>[];

        for (var i = 0; i < children.length; i += 1) {
          if (i > 0) {
            spacedChildren.add(
              SizedBox(
                width: shouldStack ? 0 : AppSpacing.xs,
                height: shouldStack ? AppSpacing.xs : 0,
              ),
            );
          }

          final child = SizedBox(width: double.infinity, child: children[i]);
          spacedChildren.add(shouldStack ? child : Expanded(child: child));
        }

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spacedChildren,
          );
        }

        return Row(children: spacedChildren);
      },
    );
  }
}

class AppIconActionButton extends StatelessWidget {
  const AppIconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 56,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}
