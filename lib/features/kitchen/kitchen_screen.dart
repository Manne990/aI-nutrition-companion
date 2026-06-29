import 'package:flutter/material.dart';

import '../../shared/widgets/app_section_card.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Kitchen', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Favorites',
          child: Text(
            'Reusable meals and common ingredients will appear here.',
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Habit suggestions',
          child: Text('Quick Log suggestions will learn from confirmed meals.'),
        ),
      ],
    );
  }
}
