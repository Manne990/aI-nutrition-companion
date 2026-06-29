import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProfile?> loadProfile();

  Future<void> saveProfile(OnboardingProfile profile);

  Future<void> clearProfile();
}

class SharedPreferencesOnboardingRepository implements OnboardingRepository {
  const SharedPreferencesOnboardingRepository(this._preferences);

  static const profileKey = 'onboarding.profile.v1';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesOnboardingRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesOnboardingRepository(preferences);
  }

  @override
  Future<OnboardingProfile?> loadProfile() async {
    final rawProfile = _preferences.getString(profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawProfile);
    if (decoded is! Map) {
      return null;
    }

    final profile = OnboardingProfile.fromJson(
      Map<String, Object?>.from(decoded),
    );
    return profile.hasRequiredConsent ? profile : null;
  }

  @override
  Future<void> saveProfile(OnboardingProfile profile) async {
    await _preferences.setString(profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clearProfile() async {
    await _preferences.remove(profileKey);
  }
}

class InMemoryOnboardingRepository implements OnboardingRepository {
  InMemoryOnboardingRepository([this._profile]);

  OnboardingProfile? _profile;

  @override
  Future<OnboardingProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(OnboardingProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clearProfile() async {
    _profile = null;
  }
}
