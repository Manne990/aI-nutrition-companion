import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme/app_theme.dart';
import '../domain/repositories/onboarding_repository.dart';

class AiNutritionCompanionApp extends StatefulWidget {
  const AiNutritionCompanionApp({super.key, this.onboardingRepository});

  final OnboardingRepository? onboardingRepository;

  @override
  State<AiNutritionCompanionApp> createState() =>
      _AiNutritionCompanionAppState();
}

class _AiNutritionCompanionAppState extends State<AiNutritionCompanionApp> {
  late final Future<OnboardingRepository> _onboardingRepository;

  @override
  void initState() {
    super.initState();
    _onboardingRepository = widget.onboardingRepository == null
        ? SharedPreferencesOnboardingRepository.create()
        : Future.value(widget.onboardingRepository);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: FutureBuilder<OnboardingRepository>(
        future: _onboardingRepository,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return AppShell(onboardingRepository: snapshot.requireData);
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
