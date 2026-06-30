import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme/app_theme.dart';
import '../domain/repositories/ai_chat_repository.dart';
import '../domain/repositories/ai_settings_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/repositories/nutrition_repository.dart';
import '../domain/repositories/onboarding_repository.dart';

class AiNutritionCompanionApp extends StatefulWidget {
  const AiNutritionCompanionApp({
    super.key,
    this.onboardingRepository,
    this.aiSettingsRepository,
    this.authRepository,
    this.healthRepository,
    this.aiChatRepository,
    this.nutritionRepository,
  });

  final OnboardingRepository? onboardingRepository;
  final AiSettingsRepository? aiSettingsRepository;
  final AuthRepository? authRepository;
  final HealthRepository? healthRepository;
  final AiChatRepository? aiChatRepository;
  final NutritionRepository? nutritionRepository;

  @override
  State<AiNutritionCompanionApp> createState() =>
      _AiNutritionCompanionAppState();
}

class _AiNutritionCompanionAppState extends State<AiNutritionCompanionApp> {
  late final Future<_AppRepositories> _repositories;

  @override
  void initState() {
    super.initState();
    _repositories = _loadRepositories();
  }

  Future<_AppRepositories> _loadRepositories() async {
    final onboardingRepository = widget.onboardingRepository == null
        ? await SharedPreferencesOnboardingRepository.create()
        : widget.onboardingRepository!;
    final aiSettingsRepository = widget.aiSettingsRepository == null
        ? await SharedPreferencesAiSettingsRepository.create()
        : widget.aiSettingsRepository!;
    final authRepository = widget.authRepository == null
        ? await SharedPreferencesAuthRepository.create()
        : widget.authRepository!;
    final healthRepository = widget.healthRepository == null
        ? await SharedPreferencesHealthRepository.create()
        : widget.healthRepository!;
    final aiChatRepository = widget.aiChatRepository == null
        ? await SharedPreferencesAiChatRepository.create()
        : widget.aiChatRepository!;

    return _AppRepositories(
      onboardingRepository: onboardingRepository,
      aiSettingsRepository: aiSettingsRepository,
      authRepository: authRepository,
      healthRepository: healthRepository,
      aiChatRepository: aiChatRepository,
      nutritionRepository: widget.nutritionRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Nutrition Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: FutureBuilder<_AppRepositories>(
        future: _repositories,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final repositories = snapshot.requireData;
            return AppShell(
              onboardingRepository: repositories.onboardingRepository,
              aiSettingsRepository: repositories.aiSettingsRepository,
              authRepository: repositories.authRepository,
              healthRepository: repositories.healthRepository,
              aiChatRepository: repositories.aiChatRepository,
              nutritionRepository: repositories.nutritionRepository,
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

class _AppRepositories {
  const _AppRepositories({
    required this.onboardingRepository,
    required this.aiSettingsRepository,
    required this.authRepository,
    required this.healthRepository,
    required this.aiChatRepository,
    this.nutritionRepository,
  });

  final OnboardingRepository onboardingRepository;
  final AiSettingsRepository aiSettingsRepository;
  final AuthRepository authRepository;
  final HealthRepository healthRepository;
  final AiChatRepository aiChatRepository;
  final NutritionRepository? nutritionRepository;
}
