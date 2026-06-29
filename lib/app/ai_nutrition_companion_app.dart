import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme/app_theme.dart';

class AiNutritionCompanionApp extends StatelessWidget {
  const AiNutritionCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
