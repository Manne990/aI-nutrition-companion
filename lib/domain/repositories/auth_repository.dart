import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';
import 'persisted_json.dart';

abstract interface class AuthRepository {
  Future<AuthAccountState> loadState();

  Future<AuthAccountState> signInWithMock();

  Future<AuthAccountState> signOut();

  Future<AuthAccountState> markProviderUnavailable(AuthProvider provider);
}

abstract interface class AuthProviderAdapter {
  AuthProvider get provider;

  Future<AuthAccountState> currentState();

  Future<AuthAccountState> signIn();

  Future<AuthAccountState> signOut();
}

class MockAuthProviderAdapter implements AuthProviderAdapter {
  const MockAuthProviderAdapter();

  @override
  AuthProvider get provider => AuthProvider.mock;

  @override
  Future<AuthAccountState> currentState() async => AuthAccountState.signedOut;

  @override
  Future<AuthAccountState> signIn() async {
    return const AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.mock,
      userLabel: 'Local mock user',
      statusDetail:
          'Mock auth is local to this device and does not sync nutrition logs.',
    );
  }

  @override
  Future<AuthAccountState> signOut() async => AuthAccountState.signedOut;
}

class SharedPreferencesAuthRepository implements AuthRepository {
  const SharedPreferencesAuthRepository(
    this._preferences, {
    this.adapter = const MockAuthProviderAdapter(),
  });

  static const stateKey = 'auth.account.state.v1';

  final SharedPreferences _preferences;
  final AuthProviderAdapter adapter;

  static Future<SharedPreferencesAuthRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAuthRepository(preferences);
  }

  @override
  Future<AuthAccountState> loadState() async {
    final rawState = _preferences.getString(stateKey);
    if (rawState == null || rawState.isEmpty) {
      return AuthAccountState.signedOut.copyWith(provider: adapter.provider);
    }
    final decoded = decodePersistedJsonMap(rawState);
    if (decoded == null) {
      return AuthAccountState.signedOut.copyWith(provider: adapter.provider);
    }
    try {
      return AuthAccountState.fromJson(decoded);
    } on TypeError {
      return AuthAccountState.signedOut.copyWith(provider: adapter.provider);
    }
  }

  @override
  Future<AuthAccountState> signInWithMock() async {
    final state = await const MockAuthProviderAdapter().signIn();
    await _saveState(state);
    return state;
  }

  @override
  Future<AuthAccountState> signOut() async {
    final state = await adapter.signOut();
    await _saveState(state);
    return state;
  }

  @override
  Future<AuthAccountState> markProviderUnavailable(
    AuthProvider provider,
  ) async {
    final state = AuthAccountState(
      status: AuthConnectionStatus.providerUnavailable,
      provider: provider,
      statusDetail:
          '${provider.label} is not configured. No project credential is bundled in this build.',
    );
    await _saveState(state);
    return state;
  }

  Future<void> _saveState(AuthAccountState state) {
    return _preferences.setString(stateKey, jsonEncode(state.toJson()));
  }
}

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    AuthAccountState initialState = AuthAccountState.signedOut,
  }) : _state = initialState;

  AuthAccountState _state;

  @override
  Future<AuthAccountState> loadState() async => _state;

  @override
  Future<AuthAccountState> signInWithMock() async {
    _state = await const MockAuthProviderAdapter().signIn();
    return _state;
  }

  @override
  Future<AuthAccountState> signOut() async {
    _state = AuthAccountState.signedOut;
    return _state;
  }

  @override
  Future<AuthAccountState> markProviderUnavailable(
    AuthProvider provider,
  ) async {
    _state = AuthAccountState(
      status: AuthConnectionStatus.providerUnavailable,
      provider: provider,
      statusDetail:
          '${provider.label} is not configured. No project credential is bundled in this build.',
    );
    return _state;
  }
}
