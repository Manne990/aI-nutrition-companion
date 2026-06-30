import 'package:ai_nutrition_companion/domain/models/auth.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth repository defaults to signed out local account state', () async {
    final repository = InMemoryAuthRepository();

    final state = await repository.loadState();

    expect(state.status, AuthConnectionStatus.signedOut);
    expect(state.provider, AuthProvider.local);
    expect(state.explainer, contains('Sign in or register'));
  });

  test(
    'register, sign in, and sign out preserve local-only boundary',
    () async {
      final repository = InMemoryAuthRepository();

      final registered = await repository.registerLocalAccount(
        email: 'PERSON@example.com',
        displayName: 'Person Name',
      );

      expect(registered.status, AuthConnectionStatus.signedIn);
      expect(registered.provider, AuthProvider.local);
      expect(registered.userLabel, 'Person Name');
      expect(registered.explainer, contains('local to this device'));
      expect(
        (await repository.loadLocalAccount())?.normalizedEmail,
        'person@example.com',
      );

      await repository.signOut();
      final signIn = await repository.signInLocalAccount(
        email: 'person@example.com',
      );

      expect(signIn.isSuccess, isTrue);
      expect(signIn.state.status, AuthConnectionStatus.signedIn);
      expect(signIn.state.userLabel, 'Person Name');

      final signedOut = await repository.signOut();

      expect(signedOut.status, AuthConnectionStatus.signedOut);
      expect(signedOut.provider, AuthProvider.local);
    },
  );

  test('sign in reports missing or invalid local credentials', () async {
    final repository = InMemoryAuthRepository();

    final missing = await repository.signInLocalAccount(
      email: 'person@example.com',
    );

    expect(missing.isSuccess, isFalse);
    expect(
      missing.errorMessage,
      'No local account exists yet. Register first.',
    );

    await repository.registerLocalAccount(
      email: 'person@example.com',
      displayName: 'Person Name',
    );
    await repository.signOut();

    final invalid = await repository.signInLocalAccount(
      email: 'other@example.com',
    );

    expect(invalid.isSuccess, isFalse);
    expect(invalid.errorMessage, 'No local account matches that email.');
  });

  test(
    'provider-unavailable state records provider without credentials',
    () async {
      final repository = InMemoryAuthRepository();

      final state = await repository.markProviderUnavailable(
        AuthProvider.supabase,
      );

      expect(state.status, AuthConnectionStatus.providerUnavailable);
      expect(state.provider, AuthProvider.supabase);
      expect(state.statusDetail, contains('No project credential'));
      expect(state.explainer, contains('Supabase Auth is not configured'));
    },
  );
}
