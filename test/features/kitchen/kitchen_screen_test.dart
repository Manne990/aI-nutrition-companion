import 'package:ai_nutrition_companion/app/theme/app_theme.dart';
import 'package:ai_nutrition_companion/domain/repositories/nutrition_repository.dart';
import 'package:ai_nutrition_companion/features/kitchen/kitchen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(ListView);
  for (var attempt = 0; attempt < 8; attempt += 1) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(scrollable, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets('Kitchen shows favorite meals and ingredient availability', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const KitchenScreen()));

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Favorite meals'), findsOneWidget);
    expect(find.text('Chicken salad'), findsWidgets);
    expect(find.text('42g protein'), findsOneWidget);
    expect(find.text('Ingredient availability'), findsOneWidget);
    expect(find.text('Plain skyr · available'), findsOneWidget);
    expect(find.text('Chicken salad · check quantity'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('Quick Log uses these meals'),
    );

    expect(find.textContaining('Quick Log uses these meals'), findsOneWidget);
  });

  testWidgets('Kitchen explains empty favorite and inventory states', (
    tester,
  ) async {
    final repository = InMemoryNutritionRepository(
      seedFoods: const [],
      seedMeals: const [],
    );

    await tester.pumpWidget(_wrap(KitchenScreen(repository: repository)));

    expect(
      find.text('Reusable meals will appear here after you log them once.'),
      findsOneWidget,
    );
    expect(
      find.text('Ingredients will appear here as the local food list grows.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Log meals and Quick Log will begin suggesting'),
      findsOneWidget,
    );
  });
}
