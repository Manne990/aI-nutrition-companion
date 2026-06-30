# AI Provider Settings And Token Storage

Status: V1 provider/credential boundary for issues #13 and #39

AI Nutrition Companion stores a user-selected provider and user-provided token
locally so chat and meal-recognition adapters can switch configuration without
hard-coded production secrets. The app chooses the current app-approved latest
model internally for the selected provider.

FoodData Central service credentials are not user settings. The app reads that
key from build/app configuration when a controlled environment provides it.
Open Food Facts read lookups do not require credentials, so the app does not
persist an Open Food Facts token or key.

## What Is Stored

Provider settings are stored in local app preferences:

- selected provider: `openai`, `gemini`, or `anthropic`
- latest model id derived by the app for that provider

Provider tokens are stored separately through the app's token storage
abstraction:

- production app path: platform secure storage via `flutter_secure_storage`
- test path: in-memory token storage

The app only exposes provider-token state such as `Token saved` or `No token
saved`. It does not show a saved provider token value after storage.

## What Is Never Committed

Do not commit:

- real provider API tokens
- real FoodData Central API keys
- signing credentials
- `.env` files containing secrets
- copied secure-storage exports
- screenshots or logs that expose provider tokens
- screenshots or logs that expose provider keys

Provider chat calls are available only after the user selects a provider and
saves a user-owned token; tests use injected transports and do not make live
calls.

## User Controls

The Me tab provides:

- provider selection
- provider-specific token setup help
- token save when no token is stored
- token deletion
- visible token state without revealing the token

Deleting a token removes the locally stored token from the current device. It
does not delete data already sent to an external provider after real provider
networking exists.

FoodData Central credentials are configured outside Settings/Me. Missing
configuration degrades to Open Food Facts and local fallback nutrition.

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
