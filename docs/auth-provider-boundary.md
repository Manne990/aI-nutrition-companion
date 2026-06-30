# Auth Provider Boundary

Status: V1 auth boundary for issue #38

AI Nutrition Companion V1 has a provider-neutral auth boundary without a custom
backend. The runnable implementation is a local account gate so tests, local CI,
and first-run product access remain deterministic.

## V1 Direction

- Require a local account before the Today, Kitchen, and Me tabs are reachable.
- Keep local account storage as the default implementation for tests and
  development.
- Model Firebase Auth and Supabase Auth as future provider options, not active
  SDK integrations.
- Do not commit a Firebase project config, Supabase project URL, publishable key,
  service-role key, OAuth secret, or other real auth credential as part of this
  issue.
- Keep nutrition logs local unless a future sync issue explicitly designs data
  flow, privacy disclosures, deletion behavior, and provider security rules.

This remains compatible with `docs/direct-api-provider-architecture.md`: client
SDK auth can be added later when the provider configuration is intentionally
introduced, but privileged server operations and app-owned secrets still require
a backend.

## Boundary Shape

The current boundary is:

- `AuthAccountState`: signed-out, signed-in local, or provider-unavailable
  state.
- `LocalAccountRecord`: stores the device-local email, display name, and
  creation timestamp used by the V1 account gate.
- `AuthRepository`: loads account state, registers a local account, validates
  local sign-in, signs out, and records provider-unavailable state.
- `AuthProviderAdapter`: provider-facing adapter seam for Firebase Auth,
  Supabase Auth, or the local V1 boundary.
- `LocalAuthProviderAdapter`: deterministic adapter used by V1 tests and the
  default app path.

The account entry screen gates app access. Register creates the local account
and starts onboarding; sign-in validates against the existing local account.
The Me tab exposes the signed-in account state and logout action.

## Firebase Auth Notes

Firebase Auth is a valid future provider direction if the app owner adds a
Firebase project intentionally. Before that work ships:

- add FlutterFire configuration through the official setup flow
- review Firebase API key restrictions, Security Rules, and App Check posture
- add signed-out, signed-in, unavailable, and error tests for the adapter
- update App Store privacy details, Google Play Data safety, and release notes
  from the final data flow

No Firebase admin credential or server secret belongs in the mobile app.

## Supabase Auth Notes

Supabase Auth is also compatible with the no-custom-backend direction if the
app owner accepts the Supabase project boundary. Before that work ships:

- add `supabase_flutter` with a project URL and publishable key only
- review Row Level Security and table policies before exposing any project data
- keep service-role and secret keys out of the mobile app
- update store disclosures and data deletion behavior before sync exists

No Supabase service-role or secret key belongs in the mobile app.

## Non-Goals

- no custom backend
- no real Firebase or Supabase project configuration
- no OAuth provider setup
- no cloud sync for meals, nutrition logs, photos, health signals, or chat
- no account deletion workflow because no real remote account is created
- no committed auth secrets

## Verification

Local tests cover:

- signed-out local account state
- signed-in local account state
- provider-unavailable state
- fresh launch blocked before product tabs
- registration to onboarding and local-account sign-in flows

Run:

```sh
bash scripts/local_ci.sh
```
