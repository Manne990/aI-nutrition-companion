import 'package:flutter/material.dart';

import '../domain/models/onboarding.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/me/me_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/today/today_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onboardingRepository});

  final OnboardingRepository onboardingRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late Future<OnboardingProfile?> _profileFuture;
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

        final screens = <Widget>[
          TodayScreen(profile: profile),
          const KitchenScreen(),
          MeScreen(profile: profile, onResetOnboarding: _resetOnboarding),
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
}
