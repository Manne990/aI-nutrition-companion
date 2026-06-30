import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';
import 'persisted_json.dart';

abstract interface class AuthRepository {
  Future<AuthAccountState> loadState();

  Future<LocalAccountRecord?> loadLocalAccount();

  Future<AuthAccountState> registerLocalAccount({
    required String email,
    required String displayName,
  });

  Future<AuthSignInResult> signInLocalAccount({required String email});

  Future<AuthAccountState> signOut();

  Future<AuthAccountState> markProviderUnavailable(AuthProvider provider);
}

abstract interface class AuthProviderAdapter {
  AuthProvider get provider;

  Future<AuthAccountState> currentState();

  Future<AuthAccountState> signIn();

  Future<AuthAccountState> signOut();
}

class LocalAuthProviderAdapter implements AuthProviderAdapter {
  const LocalAuthProviderAdapter();

  @override
  AuthProvider get provider => AuthProvider.local;

  @override
  Future<AuthAccountState> currentState() async => AuthAccountState.signedOut;

  @override
  Future<AuthAccountState> signIn() async {
    return const AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.local,
      userLabel: 'Local user',
      statusDetail: 'Signed in with a local account on this device.',
    );
  }

  @override
  Future<AuthAccountState> signOut() async => AuthAccountState.signedOut;
}

class SharedPreferencesAuthRepository implements AuthRepository {
  const SharedPreferencesAuthRepository(
    this._preferences, {
    this.adapter = const LocalAuthProviderAdapter(),
    this.now,
  });

  static const stateKey = 'auth.account.state.v1';
  static const accountKey = 'auth.local.account.v1';

  final SharedPreferences _preferences;
  final AuthProviderAdapter adapter;
  final DateTime Function()? now;

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
  Future<LocalAccountRecord?> loadLocalAccount() async {
    final rawAccount = _preferences.getString(accountKey);
    if (rawAccount == null || rawAccount.isEmpty) {
      return null;
    }
    final decoded = decodePersistedJsonMap(rawAccount);
    if (decoded == null) {
      return null;
    }
    try {
      return LocalAccountRecord.fromJson(decoded);
    } on TypeError {
      return null;
    }
  }

  @override
  Future<AuthAccountState> registerLocalAccount({
    required String email,
    required String displayName,
  }) async {
    final account = LocalAccountRecord(
      email: email,
      displayName: displayName.trim().isEmpty ? 'Local user' : displayName,
      createdAt: now?.call() ?? DateTime.now(),
    );
    await _preferences.setString(accountKey, jsonEncode(account.toJson()));
    final state = AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.local,
      userLabel: account.displayName,
      statusDetail: 'Signed in with ${account.normalizedEmail}.',
    );
    await _saveState(state);
    return state;
  }

  @override
  Future<AuthSignInResult> signInLocalAccount({required String email}) async {
    final account = await loadLocalAccount();
    final currentState = await loadState();
    if (account == null) {
      return AuthSignInResult.failure(
        state: currentState.copyWith(
          status: AuthConnectionStatus.signedOut,
          provider: AuthProvider.local,
          statusDetail: 'Register before signing in on this device.',
        ),
        message: 'No local account exists yet. Register first.',
      );
    }
    if (account.normalizedEmail != normalizeAccountEmail(email)) {
      return AuthSignInResult.failure(
        state: currentState.copyWith(
          status: AuthConnectionStatus.signedOut,
          provider: AuthProvider.local,
          statusDetail: 'Check the email used when registering on this device.',
        ),
        message: 'No local account matches that email.',
      );
    }
    final state = AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.local,
      userLabel: account.displayName,
      statusDetail: 'Signed in with ${account.normalizedEmail}.',
    );
    await _saveState(state);
    return AuthSignInResult.success(state);
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
    LocalAccountRecord? initialAccount,
  }) : _state = initialState,
       _account = initialAccount;

  AuthAccountState _state;
  LocalAccountRecord? _account;

  @override
  Future<AuthAccountState> loadState() async => _state;

  @override
  Future<LocalAccountRecord?> loadLocalAccount() async => _account;

  @override
  Future<AuthAccountState> registerLocalAccount({
    required String email,
    required String displayName,
  }) async {
    _account = LocalAccountRecord(
      email: email,
      displayName: displayName.trim().isEmpty ? 'Local user' : displayName,
      createdAt: DateTime.now(),
    );
    _state = AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.local,
      userLabel: _account!.displayName,
      statusDetail: 'Signed in with ${_account!.normalizedEmail}.',
    );
    return _state;
  }

  @override
  Future<AuthSignInResult> signInLocalAccount({required String email}) async {
    final account = _account;
    if (account == null) {
      return AuthSignInResult.failure(
        state: _state.copyWith(
          status: AuthConnectionStatus.signedOut,
          provider: AuthProvider.local,
          statusDetail: 'Register before signing in on this device.',
        ),
        message: 'No local account exists yet. Register first.',
      );
    }
    if (account.normalizedEmail != normalizeAccountEmail(email)) {
      return AuthSignInResult.failure(
        state: _state.copyWith(
          status: AuthConnectionStatus.signedOut,
          provider: AuthProvider.local,
          statusDetail: 'Check the email used when registering on this device.',
        ),
        message: 'No local account matches that email.',
      );
    }
    _state = AuthAccountState(
      status: AuthConnectionStatus.signedIn,
      provider: AuthProvider.local,
      userLabel: account.displayName,
      statusDetail: 'Signed in with ${account.normalizedEmail}.',
    );
    return AuthSignInResult.success(_state);
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
