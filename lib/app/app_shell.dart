import 'package:flutter/material.dart';

import '../domain/models/ai_settings.dart';
import '../domain/models/auth.dart';
import '../domain/models/health.dart';
import '../domain/models/onboarding.dart';
import '../domain/repositories/ai_chat_repository.dart';
import '../domain/repositories/ai_settings_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/repositories/nutrition_repository.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/me/me_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/today/today_screen.dart';
import '../services/adapters/ai_chat_adapter.dart';
import '../services/adapters/meal_recognition_adapter.dart';
import '../services/adapters/nutrition_companion_adapter.dart';
import '../services/adapters/nutrition_lookup_adapters.dart';
import 'service_credentials.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onboardingRepository,
    required this.aiSettingsRepository,
    required this.authRepository,
    required this.healthRepository,
    required this.aiChatRepository,
    this.nutritionRepository,
    this.serviceCredentials = const AppServiceCredentials(),
    this.foodDataCentralSearchClient,
    this.now,
  });

  final OnboardingRepository onboardingRepository;
  final AiSettingsRepository aiSettingsRepository;
  final AuthRepository authRepository;
  final HealthRepository healthRepository;
  final AiChatRepository aiChatRepository;
  final NutritionRepository? nutritionRepository;
  final AppServiceCredentials serviceCredentials;
  final FoodDataCentralSearchClient? foodDataCentralSearchClient;
  final DateTime? now;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late Future<OnboardingProfile?> _profileFuture;
  late Future<AiAdapterConfiguration> _aiConfigurationFuture;
  late Future<AuthAccountState> _authStateFuture;
  late Future<HealthConnectionState> _healthStateFuture;
  late Future<
    ({
      AiAdapterConfiguration ai,
      AuthAccountState auth,
      HealthConnectionState health,
    })
  >
  _runtimeStateFuture;
  late Future<NutritionRepository> _nutritionRepositoryFuture;
  OnboardingProfile? _profile;
  OnboardingProfile? _nutritionRepositoryProfile;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.wb_sunny_outlined),
      selectedIcon: Icon(Icons.wb_sunny),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.restaurant_menu_outlined),
      selectedIcon: Icon(Icons.restaurant_menu),
      label: 'Kitchen',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Me',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.onboardingRepository.loadProfile();
    _aiConfigurationFuture = widget.aiSettingsRepository
        .loadAdapterConfiguration();
    _authStateFuture = widget.authRepository.loadState();
    _healthStateFuture = widget.healthRepository.loadState();
    _runtimeStateFuture = _loadRuntimeState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnboardingProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        _profile ??= snapshot.data;
        final profile = _profile;
        if (profile == null) {
          return OnboardingScreen(onCompleted: _completeOnboarding);
        }

        _ensureNutritionRepository(profile);

        return FutureBuilder<
          ({
            AiAdapterConfiguration ai,
            AuthAccountState auth,
            HealthConnectionState health,
          })
        >(
          future: _runtimeStateFuture,
          builder: (context, runtimeSnapshot) {
            if (!runtimeSnapshot.hasData) {
              return const Scaffold(
                body: SafeArea(
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final aiConfiguration = runtimeSnapshot.requireData.ai;
            final authState = runtimeSnapshot.requireData.auth;
            final healthState = runtimeSnapshot.requireData.health;
            return FutureBuilder<NutritionRepository>(
              future: _nutritionRepositoryFuture,
              builder: (context, nutritionSnapshot) {
                if (!nutritionSnapshot.hasData) {
                  return const Scaffold(
                    body: SafeArea(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final nutritionRepository = nutritionSnapshot.requireData;
                final screens = <Widget>[
                  TodayScreen(
                    profile: profile,
                    adapter: MockNutritionCompanionAdapter(
                      configuration: aiConfiguration,
                    ),
                    repository: nutritionRepository,
                    chatRepository: widget.aiChatRepository,
                    aiConfiguration: aiConfiguration,
                    aiChatAdapter: _createAiChatAdapter(aiConfiguration),
                    mealRecognitionAdapter: MockMealRecognitionAdapter(
                      configuration: aiConfiguration,
                    ),
                    now: widget.now,
                    healthSignals: healthState.isConnected
                        ? healthState.signals
                        : null,
                  ),
                  KitchenScreen(repository: nutritionRepository),
                  MeScreen(
                    profile: profile,
                    nutritionRepository: nutritionRepository,
                    aiSettingsRepository: widget.aiSettingsRepository,
                    authRepository: widget.authRepository,
                    authState: authState,
                    healthRepository: widget.healthRepository,
                    healthState: healthState,
                    onAiSettingsChanged: _reloadAiConfiguration,
                    onAuthStateChanged: _reloadAuthState,
                    onHealthStateChanged: _reloadHealthState,
                    onResetOnboarding: _resetOnboarding,
                    onResetNutritionProgress: () =>
                        _resetNutritionProgress(nutritionRepository),
                  ),
                ];

                return Scaffold(
                  body: SafeArea(
                    bottom: false,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: screens,
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _selectedIndex,
                    destinations: _destinations,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _completeOnboarding(OnboardingProfile profile) async {
    await widget.onboardingRepository.saveProfile(profile);
    final nutritionRepository = await _loadNutritionRepository(profile);
    await nutritionRepository.saveBackupPreference(profile.backupPreference);
    final healthState = profile.healthConnectionApproved
        ? await widget.healthRepository.requestConnection()
        : await widget.healthRepository.loadState();
    setState(() {
      _profile = profile;
      _selectedIndex = 0;
      _profileFuture = Future.value(profile);
      _healthStateFuture = Future.value(healthState);
      _runtimeStateFuture = _loadRuntimeState();
      _nutritionRepositoryProfile = profile;
      _nutritionRepositoryFuture = Future.value(nutritionRepository);
    });
  }

  Future<void> _resetOnboarding() async {
    await widget.onboardingRepository.clearProfile();
    setState(() {
      _profile = null;
      _selectedIndex = 0;
      _profileFuture = Future<OnboardingProfile?>.value();
    });
  }

  Future<void> _resetNutritionProgress(
    NutritionRepository nutritionRepository,
  ) async {
    await nutritionRepository.clearLocalProgress();
    setState(() {});
  }

  Future<void> _reloadAiConfiguration() async {
    setState(() {
      _aiConfigurationFuture = widget.aiSettingsRepository
          .loadAdapterConfiguration();
      _runtimeStateFuture = _loadRuntimeState();
      _nutritionRepositoryProfile = null;
    });
  }

  Future<void> _reloadAuthState() async {
    setState(() {
      _authStateFuture = widget.authRepository.loadState();
      _runtimeStateFuture = _loadRuntimeState();
    });
  }

  Future<void> _reloadHealthState() async {
    setState(() {
      _healthStateFuture = widget.healthRepository.loadState();
      _runtimeStateFuture = _loadRuntimeState();
    });
  }

  Future<
    ({
      AiAdapterConfiguration ai,
      AuthAccountState auth,
      HealthConnectionState health,
    })
  >
  _loadRuntimeState() async {
    return (
      ai: await _aiConfigurationFuture,
      auth: await _authStateFuture,
      health: await _healthStateFuture,
    );
  }

  void _ensureNutritionRepository(OnboardingProfile profile) {
    if (_nutritionRepositoryProfile == profile) {
      return;
    }

    _nutritionRepositoryProfile = profile;
    _nutritionRepositoryFuture = _loadNutritionRepository(profile);
  }

  Future<NutritionRepository> _loadNutritionRepository(
    OnboardingProfile profile,
  ) async {
    final repository = widget.nutritionRepository;
    if (repository != null) {
      return repository;
    }

    return SharedPreferencesNutritionRepository.create(
      seedGoal: profile.toNutritionGoal(calories: 2200),
      seedPreferences: profile.toUserPreferences(),
      seedBackupPreference: profile.backupPreference,
      foodDataCentralApiKey:
          widget.serviceCredentials.configuredFoodDataCentralApiKey,
      foodDataCentralSearchClient: widget.foodDataCentralSearchClient,
    );
  }

  AiChatAdapter _createAiChatAdapter(AiAdapterConfiguration configuration) {
    if (configuration.settings.usesMockProvider) {
      return const MockAiChatAdapter();
    }
    return RealProviderAiChatAdapter(
      configuration: configuration,
      readToken: widget.aiSettingsRepository.readProviderToken,
    );
  }
}
