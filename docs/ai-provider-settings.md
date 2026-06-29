# AI Provider Settings And Token Storage

Status: V1 provider/token boundary for issue #13

AI Nutrition Companion runs in deterministic mock mode by default. V1 can store
a user-selected provider, model, and user-provided token locally so future chat
and meal-recognition adapters can switch configuration without hard-coded
production secrets.

## What Is Stored

Provider settings are stored in local app preferences:

- selected provider: `mock`, `openai`, or `anthropic`
- selected model for that provider

Provider tokens are stored separately through the app's token storage
abstraction:

- production app path: platform secure storage via `flutter_secure_storage`
- test path: in-memory token storage

The app only exposes token state such as `Token saved` or `No token saved`.
It does not show the saved token value after storage.

## What Is Never Committed

Do not commit:

- real provider API tokens
- signing credentials
- `.env` files containing secrets
- copied secure-storage exports
- screenshots or logs that expose provider tokens

Mock AI remains the default for local development and CI. Real provider calls
remain stubbed behind adapter configuration until explicit network-provider work
is added.

## User Controls

The Me tab provides:

- provider selection
- model selection
- token save/update
- token deletion
- visible token state without revealing the token

Deleting a token removes the locally stored token from the current device. It
does not delete data already sent to an external provider after real provider
networking exists.

## Backend Boundary

V1 does not require a backend for user-provided local tokens. Revisit the
backend decision before adding:

- server-held provider secrets
- shared accounts
- billing or provider usage quotas
- family/team sync
- cross-device token sync
- server-side rate limiting
- provider terms that prohibit direct mobile calls
- production analytics tied to personal health or nutrition data

If any of those features are introduced, update the privacy policy, App Store
privacy details, Google Play Data safety form, and in-app disclosures before
release.
