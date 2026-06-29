import 'package:ai_nutrition_companion/app/ai_nutrition_companion_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders Today and bottom navigation', (tester) async {
    await tester.pumpWidget(const AiNutritionCompanionApp());

    expect(find.text('What should I eat next?'), findsOneWidget);
    expect(find.text('Skyr bowl with berries'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between V1 sections', (tester) async {
    await tester.pumpWidget(const AiNutritionCompanionApp());

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('AI provider'), findsOneWidget);
  });
}
