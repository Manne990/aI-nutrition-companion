import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/shared/widgets/app_action_buttons.dart';
import 'package:ai_nutrition_companion/shared/widgets/app_chip.dart';
import 'package:ai_nutrition_companion/shared/widgets/design_system_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('design system demo renders core primitives', (tester) async {
    await tester.pumpWidget(_wrap(const DesignSystemDemo()));

    expect(find.text('Design system demo'), findsOneWidget);
    expect(find.text('Reusable meal card'), findsOneWidget);
    expect(find.text('Suggested next'), findsOneWidget);
    expect(find.text('High protein'), findsOneWidget);
    expect(find.text('AI-estimated'), findsOneWidget);
    expect(find.text('Sounds perfect'), findsOneWidget);
    expect(find.byTooltip('Refresh suggestion'), findsOneWidget);
    expect(find.text('Yes, show me'), findsOneWidget);
  });

  testWidgets('primitive controls stay usable on a small phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            const Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppChip(label: 'Very practical nutrition chip'),
                AppChip(label: 'Database-verified', tone: AppChipTone.success),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Sounds perfect',
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIconActionButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh suggestion',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sounds perfect'), findsOneWidget);
    expect(find.byTooltip('Refresh suggestion'), findsOneWidget);
  });

  testWidgets('action button groups stack long labels on compact widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Center(
          child: SizedBox(
            width: 320,
            child: AppActionButtonGroup(
              children: [
                AppSecondaryButton(
                  label: 'Save provider token',
                  icon: Icons.key,
                  onPressed: () {},
                ),
                AppSecondaryButton(
                  label: 'Delete provider token',
                  icon: Icons.delete_outline,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final saveTop = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, 'Save provider token'),
    );
    final deleteTop = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, 'Delete provider token'),
    );
    expect(deleteTop.dy, greaterThan(saveTop.dy));
    expect(deleteTop.dx, saveTop.dx);
  });

  testWidgets('action button groups stay side by side when space allows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Center(
          child: SizedBox(
            width: 600,
            child: AppActionButtonGroup(
              children: [
                AppSecondaryButton(
                  label: 'Change',
                  icon: Icons.refresh,
                  onPressed: () {},
                ),
                AppSecondaryButton(
                  label: 'Not now',
                  icon: Icons.schedule_outlined,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final changeTop = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, 'Change'),
    );
    final deferTop = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, 'Not now'),
    );
    expect(deferTop.dy, changeTop.dy);
    expect(deferTop.dx, greaterThan(changeTop.dx));
  });
}
