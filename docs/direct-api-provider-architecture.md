# Direct API Provider Architecture

Status: V1 architecture decision for issue #35
Last reviewed against provider sources: 2026-06-30

AI Nutrition Companion V1 should prefer direct app integrations when the
provider contract is public, user-owned, or explicitly client-safe. A custom
backend or proxy is required before any app-owned secret, elevated provider key,
shared quota policy, or server-side data sync is introduced.

This decision is explicit but reversible. If a future feature needs server-held
credentials, cross-device nutrition sync, shared rate limiting, provider
webhooks, billing, or admin data access, add the backend boundary then and keep
the mobile app free of app-owned secrets.

## Source References

- Open Food Facts API:
  https://openfoodfacts.github.io/openfoodfacts-server/api/
- USDA FoodData Central API guide:
  https://fdc.nal.usda.gov/api-guide
- Firebase for Flutter setup:
  https://firebase.google.com/docs/flutter/setup
- Firebase Authentication for Flutter:
  https://firebase.google.com/docs/auth/flutter/start
- Firebase API key guidance:
  https://firebase.google.com/docs/projects/api-keys
- Supabase Flutter quickstart:
  https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Supabase API key guidance:
  https://supabase.com/docs/guides/getting-started/api-keys

## V1 Recommendation

V1 should use these boundaries:

- Open Food Facts: direct read-only app calls for packaged-food lookup by
  barcode, with an app-identifying User-Agent and deterministic test transport.
- FoodData Central: direct app calls only with a user-provided or runtime
  injected data.gov key; missing-key behavior must be explicit and usable.
- Firebase Auth or Supabase Auth: provider SDK integration may run in the app
  with provider-approved client configuration, while mock/local auth remains the
  default test path.
- AI providers: user-provided tokens may be stored locally through secure
  platform storage; app-owned AI provider keys require a backend.
- Local storage: local nutrition logs, settings, mock data, and caches may stay
  on device unless sync is explicitly designed later.

Do not ship app-owned API secrets in the mobile binary. Do not hide shared
production keys in Dart constants, Flutter assets, plist/json config files,
Gradle properties committed to git, screenshots, tests, or fixtures.

## Provider Credential Matrix

| Service | V1 direct app use | Credential class | Mobile binary rule | Backend/proxy trigger |
| --- | --- | --- | --- | --- |
| Open Food Facts | Yes, for read-only product lookup. | No read API key; custom User-Agent identifies the app. Write flows need Open Food Facts account/session handling. | Include only app identity metadata such as app name, version, and contact channel. Do not include shared account passwords. | Required for shared write credentials, contribution moderation, bulk sync, traffic above direct-user limits, or server-side cache/import jobs. |
| FoodData Central | Yes, only with build/app configuration for a controlled environment and explicit missing-configuration fallback. | API key assigned to a key holder; documentation says the holder is responsible for keeping it non-public. | Do not commit real FoodData Central keys. Do not expose FoodData Central key entry in user settings. | Required for shared production quota management, server-side search aggregation, hidden provider credentials, or broad distribution with an app-owned key. |
| Firebase Auth | Yes, through FlutterFire and `firebase_auth` if identity becomes active. | Firebase app configuration and Firebase API keys are public-by-design identifiers when restricted to Firebase services; auth state is user-owned. | Firebase config may be committed only after project ownership, API restrictions, Security Rules, and App Check posture are reviewed. Do not include non-Firebase API keys or admin credentials. | Required for privileged admin actions, custom claims management, server-trusted sync, callable functions with server secrets, or provider secrets outside Firebase's client model. |
| Supabase Auth | Yes, through `supabase_flutter` with a project URL and publishable key if selected. | Publishable key is client-safe; legacy anon key is low-privilege client use; secret and service-role keys are elevated backend secrets. | A publishable key may be bundled only with Row Level Security and auth policies reviewed. Never ship `sb_secret_*` or `service_role` keys. | Required for secret/service-role operations, admin data access, bypassing RLS, server-side jobs, or policies that cannot safely expose client access. |
| AI providers | Yes, only with user-provided tokens and explicit opt-in. | User-owned token stored locally. App-owned model/provider keys are secrets. | Do not commit, log, screenshot, or display saved token values after storage. | Required for app-owned AI keys, central billing, quota controls, audit logging, model mediation, or server-side prompt enrichment. |
| Health data providers | Not active in V1 beyond mock scaffolding. | Platform user permission and local state. | Do not add HealthKit/Health Connect entitlements or credentials without a separate implementation issue and store-disclosure update. | Required for cross-device sync, server analytics, or any server-held health/nutrition profile. |

## Direct Integration Rules

Every direct provider implementation should preserve these constraints:

- Keep a domain boundary such as `NutritionLookupProvider` or an auth/provider
  abstraction between UI and transport details.
- Inject HTTP clients, clocks, secure storage, and provider configuration so
  local CI does not make live network calls.
- Preserve source metadata in user-visible nutrition state: provider id,
  observed time, lookup mode, and fallback reason when known.
- Treat provider errors, rate limits, missing credentials, and malformed data as
  first-class product states rather than crashes or silent empty values.
- Keep mock providers available for local development, tests, screenshots, and
  store review notes.
- Do not cache external data without source, time, and provider identity.
- Re-check provider docs before production release because direct-use terms,
  quotas, and key handling guidance can change.

## V1 Nutrition Lookup Policy

The V1 lookup service uses explicit provider ordering instead of hidden runtime
branching:

- Barcode lookups should prefer Open Food Facts before generic-food providers.
- Generic food search should prefer FoodData Central when a user-provided or
  runtime-injected key is available, then local fallback.
- Provider errors, malformed data, missing credentials, and timeouts are source
  gaps. They should be carried into fallback messages rather than treated as
  empty nutrition.
- Successful external lookups may be cached only when the cached food preserves
  provider identity and an observed timestamp in `SourceMetadata`.
- Cache is a resilience fallback, not a freshness authority. Fresh provider
  results are checked before cache hits, and a fresh verified result supersedes
  a disagreeing cached result.
- Local fallback can explain why a provider was unavailable, but it remains
  fallback nutrition until the user confirms or a verified provider supplies
  facts.

## Service Notes

### Open Food Facts

Open Food Facts is the preferred first packaged-food provider for barcode read
lookup. Its API documentation identifies v3 as the current integration path,
documents rate limits for product and search queries, and states that read
operations do not require authentication beyond a custom User-Agent. It also
asks applications to identify themselves with an app name, version, and contact
channel.

For V1, the app may call Open Food Facts directly for barcode read paths. The
implementation should avoid search-as-you-type behavior, preserve an offline or
local fallback, and show source gaps because community-supplied nutrition data
can be incomplete or unreliable. Write, image upload, shared account, or bulk
data features are outside this direct-read decision.

### FoodData Central

FoodData Central provides REST search and details endpoints for nutrient data.
Its API guide requires a data.gov API key on each request and says the API key
holder is responsible for ensuring the key is not publicly available. The
documentation examples include `DEMO_KEY` for exploration, but its lower rate
limits make it inappropriate as a production app key.

For V1, FoodData Central may be wired as a direct provider only when a controlled
build/app runtime injects a key through configuration. Users should not manage
FoodData Central credentials in Settings. If the product owner wants one shared
FoodData Central key for broad production use, that key is app-owned and should
move behind a backend/proxy before release.

### Firebase Auth

Firebase Auth can satisfy a login boundary without a custom auth backend. The
Flutter setup flow uses FlutterFire configuration and the `firebase_auth`
plugin. Firebase documentation distinguishes Firebase API keys from typical
secrets: restricted Firebase service keys identify the Firebase project/app, and
authorization depends on IAM, Security Rules, and App Check rather than hiding
the client key.

For V1, choose Firebase Auth only after accepting the Firebase project
configuration and store-disclosure surface. Keep the local account gate working
because nutrition logs remain local unless a separate sync feature is
implemented.

### Supabase Auth

Supabase Auth is also compatible with a no-custom-backend V1 login boundary.
The Flutter quickstart initializes `supabase_flutter` with the project URL and a
publishable key. Supabase documentation classifies publishable keys as safe to
expose in web, mobile, desktop, source, and build artifacts, while secret keys
and legacy service-role keys are backend-only elevated credentials.

For V1, choose Supabase Auth only with Row Level Security and auth policies
reviewed for every table the app can reach. Never bundle a secret or
service-role key in the mobile app, even for localhost or testing.

## When A Backend Becomes Required

Add a backend or provider proxy before implementing any of these:

- app-owned FoodData Central, AI provider, Supabase secret/service-role, or
  non-Firebase Google API key use
- shared provider quota, billing, usage accounting, or abuse controls
- server-side nutrition cache, data normalization, deduplication, or bulk
  import/export
- account sync for meals, nutrition logs, health signals, photos, or chat
  history
- provider webhooks, admin operations, custom claims, or privileged auth flows
- Open Food Facts write/upload through shared app credentials
- any provider terms that prohibit direct mobile calls for the intended use

Backend introduction must include a new privacy and data-flow review. The
mobile app should still keep mock/local provider paths for CI and graceful
offline behavior.

## Documentation Dependencies

- `docs/auth-provider-boundary.md` records the V1 provider-neutral auth seam and
  keeps the local account gate as the default until a real Firebase or Supabase
  project is intentionally introduced.
- `docs/ai-provider-settings.md` remains the user-token storage boundary for AI
  providers and should be extended for FoodData Central user keys if #39 adds
  nutrition credentials.
- `docs/health-data-scaffolding.md` remains the health permission boundary.
- `docs/release-readiness.md` remains the store-submission checklist and should
  be rechecked after any real provider networking or auth SDK is added.
