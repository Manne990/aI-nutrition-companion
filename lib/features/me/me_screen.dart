import 'package:flutter/material.dart';

import '../../shared/widgets/app_section_card.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Me', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Goals and preferences',
          child: Text(
            'Protein target, dietary preferences, allergies, and coaching tone.',
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'AI provider',
          child: Text(
            'Mock mode is enabled until a provider, model, and local token are configured.',
          ),
        ),
        const SizedBox(height: 16),
        const AppSectionCard(
          title: 'Health and privacy',
          child: Text(
            'Health permissions, AI boundaries, and nutrition disclaimers live here.',
          ),
        ),
      ],
    );
  }
}
