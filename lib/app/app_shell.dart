import 'package:flutter/material.dart';

import '../domain/models/ai_settings.dart';
import '../domain/models/health.dart';
import '../domain/models/onboarding.dart';
import '../domain/repositories/ai_chat_repository.dart';
import '../domain/repositories/ai_settings_repository.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/me/me_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/today/today_screen.dart';
import '../services/adapters/meal_recognition_adapter.dart';
import '../services/adapters/nutrition_companion_adapter.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onboardingRepository,
    required this.aiSettingsRepository,
    required this.healthRepository,
    required this.aiChatRepository,
  });

  final OnboardingRepository onboardingRepository;
  final AiSettingsRepository aiSettingsRepository;
  final HealthRepository healthRepository;
  final AiChatRepository aiChatRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late Future<OnboardingProfile?> _profileFuture;
  late Future<AiAdapterConfiguration> _aiConfigurationFuture;
  late Future<HealthConnectionState> _healthStateFuture;
  late Future<({AiAdapterConfiguration ai, HealthConnectionState health})>
  _runtimeStateFuture;
  OnboardingProfile? _profile;

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

        return FutureBuilder<
          ({AiAdapterConfiguration ai, HealthConnectionState health})
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
            final healthState = runtimeSnapshot.requireData.health;
            final screens = <Widget>[
              TodayScreen(
                profile: profile,
                adapter: MockNutritionCompanionAdapter(
                  configuration: aiConfiguration,
                ),
                chatRepository: widget.aiChatRepository,
                aiConfiguration: aiConfiguration,
                mealRecognitionAdapter: MockMealRecognitionAdapter(
                  configuration: aiConfiguration,
                ),
                healthSignals: healthState.isConnected
                    ? healthState.signals
                    : null,
              ),
              const KitchenScreen(),
              MeScreen(
                profile: profile,
                aiSettingsRepository: widget.aiSettingsRepository,
                healthRepository: widget.healthRepository,
                healthState: healthState,
                onAiSettingsChanged: _reloadAiConfiguration,
                onHealthStateChanged: _reloadHealthState,
                onResetOnboarding: _resetOnboarding,
              ),
            ];

            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: IndexedStack(index: _selectedIndex, children: screens),
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
  }

  Future<void> _completeOnboarding(OnboardingProfile profile) async {
    await widget.onboardingRepository.saveProfile(profile);
    setState(() {
      _profile = profile;
      _selectedIndex = 0;
      _profileFuture = Future.value(profile);
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

  Future<void> _reloadAiConfiguration() async {
    setState(() {
      _aiConfigurationFuture = widget.aiSettingsRepository
          .loadAdapterConfiguration();
      _runtimeStateFuture = _loadRuntimeState();
    });
  }

  Future<void> _reloadHealthState() async {
    setState(() {
      _healthStateFuture = widget.healthRepository.loadState();
      _runtimeStateFuture = _loadRuntimeState();
    });
  }

  Future<({AiAdapterConfiguration ai, HealthConnectionState health})>
  _loadRuntimeState() async {
    return (ai: await _aiConfigurationFuture, health: await _healthStateFuture);
  }
}
