# External Provider Settings And Credential Storage

Status: V1 provider/credential boundary for issues #13 and #39

AI Nutrition Companion runs in deterministic mock mode by default. V1 can store
a user-selected provider, model, and user-provided token locally so future chat
and meal-recognition adapters can switch configuration without hard-coded
production secrets.

The app can also store a user-provided FoodData Central API key for direct
nutrition lookup work. Open Food Facts read lookups do not require credentials,
so the app does not persist an Open Food Facts token or key.

## What Is Stored

Provider settings are stored in local app preferences:

- selected provider: `mock`, `openai`, or `anthropic`
- selected model for that provider

Provider tokens are stored separately through the app's token storage
abstraction:

- production app path: platform secure storage via `flutter_secure_storage`
- test path: in-memory token storage

FoodData Central API keys are stored through the same secure-storage
abstraction under a separate storage key from AI provider tokens.

The app only exposes credential state such as `Token saved`, `No token saved`,
`FoodData Central key saved`, or `No FoodData Central key`. It does not show a
saved secret value after storage.

## What Is Never Committed

Do not commit:

- real provider API tokens
- real FoodData Central API keys
- signing credentials
- `.env` files containing secrets
- copied secure-storage exports
- screenshots or logs that expose provider tokens
- screenshots or logs that expose provider keys

Mock AI remains the default for local development and CI. Real provider calls
remain stubbed behind adapter configuration until explicit network-provider work
is added.

## User Controls

The Me tab provides:

- provider selection
- model selection
- token save/update
- token deletion
- FoodData Central API key save/update
- FoodData Central API key deletion
- visible token state without revealing the token
- visible key state without revealing the key

Deleting a token removes the locally stored token from the current device. It
does not delete data already sent to an external provider after real provider
networking exists.

Deleting a FoodData Central key removes the locally stored key from the current
device. It does not remove cached nutrition results that may be created by
future lookup work.

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
