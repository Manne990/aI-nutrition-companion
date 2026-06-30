import 'package:ai_nutrition_companion/domain/models/auth.dart';
import 'package:ai_nutrition_companion/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth repository defaults to signed out mock state', () async {
    final repository = InMemoryAuthRepository();

    final state = await repository.loadState();

    expect(state.status, AuthConnectionStatus.signedOut);
    expect(state.provider, AuthProvider.mock);
    expect(state.explainer, contains('Use the app signed out'));
  });

  test('mock sign-in and sign-out preserve local-only boundary', () async {
    final repository = InMemoryAuthRepository();

    final signedIn = await repository.signInWithMock();

    expect(signedIn.status, AuthConnectionStatus.signedIn);
    expect(signedIn.provider, AuthProvider.mock);
    expect(signedIn.userLabel, 'Local mock user');
    expect(signedIn.explainer, contains('Nutrition logs still stay'));

    final signedOut = await repository.signOut();

    expect(signedOut.status, AuthConnectionStatus.signedOut);
    expect(signedOut.provider, AuthProvider.mock);
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
