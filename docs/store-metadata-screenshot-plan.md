# V1 Store Metadata And Screenshot Plan

Status: V1 planning artifact for issue #58
Last reviewed against repository behavior: 2026-06-30

This document prepares App Store and Google Play listing content for the
current V1 Flutter app. It is a working plan, not final legal, medical,
privacy, or store-review approval. Replace all TODO placeholders with hosted
production values before public testing or production submission.

## Current App Boundaries

- App name: `AI Nutrition Companion`.
- Version in `pubspec.yaml`: `1.0.0+1`.
- Platforms: iOS and Android.
- Default mode: local mock companion, mock AI responses, deterministic mock
  meal recognition, local nutrition data, and local-first app state.
- Backend: no custom backend exists in this repository.
- Accounts: mock local auth only; no real account provider or cloud sync.
- Nutrition lookup: deterministic local/mock defaults unless a user-provided
  or runtime-injected provider key is available.
- AI provider tokens: user-provided tokens are optional and must not be
  committed, bundled, or included in diagnostics or screenshots.
- Health data: mock health scaffolding only; no HealthKit entitlement, Android
  Health Connect permission, or native health bridge is enabled.
- Photos: meal photo flows exist for user-selected logging. The current local
  default uses deterministic mock recognition.
- Diagnostics, analytics, crash reporting, ads, billing, and automatic support
  upload are not configured.

## Required Placeholder Values

Keep these explicit until final production assets exist:

| Field | Current value |
| --- | --- |
| Privacy policy URL | TODO before production submission. |
| Support URL | TODO before production submission. |
| Marketing URL | TODO optional before production submission. |
| Data deletion request URL or support path | TODO before accounts, cloud sync, or remote user data. |
| App Store Connect app id | TODO after app record creation. |
| Google Play package listing | TODO after Play Console app creation. |
| Final app icon and launch assets | TODO before store submission. |
| Final screenshots | TODO after capture from release candidate builds. |

## App Store Metadata Draft

| Field | Draft |
| --- | --- |
| Name | AI Nutrition Companion |
| Subtitle | Meal guidance for your next choice |
| Primary category | Health & Fitness |
| Secondary category | Food & Drink |
| Promotional text | Practical meal suggestions, quick logging, and AI companion prompts for deciding what to eat next. |
| Short description for internal review | Local-first nutrition companion with mock AI defaults and optional user-configured providers. |
| Keywords | nutrition,meal planner,food log,protein,wellness,AI companion,healthy eating |
| Support URL | TODO before production submission. |
| Marketing URL | TODO optional before production submission. |
| Privacy policy URL | TODO before production submission. |
| Copyright | TODO release owner legal name. |
| Age rating notes | Nutrition and wellness guidance only; no medical diagnosis or treatment. Recheck final questionnaire answers before submission. |

### App Store Description Draft

AI Nutrition Companion helps you decide what to eat next with practical,
low-friction guidance. Start from the Today screen to see a suggested next
meal, daily nutrition context, quick logging options, and companion prompts
that explain what would help your current day.

V1 focuses on local-first meal guidance. You can log meals, review nutrition
estimates, reuse common meals from Kitchen, and manage goals, preferences,
privacy, health, and AI provider settings from Me. Mock AI and local fallback
data are the default development and testing modes.

The app provides practical nutrition support, not medical diagnosis,
treatment, or emergency advice. If real provider mode is enabled in a future
build, requests may be sent to the provider configured by the user under that
provider's terms.

## Google Play Metadata Draft

| Field | Draft |
| --- | --- |
| App name | AI Nutrition Companion |
| Short description | Practical meal guidance for what to eat next. |
| Full description | See Google Play full description draft below. |
| App category | Health & Fitness |
| Tags | Nutrition, Meal planning, Wellness |
| Contact email | TODO release support contact. |
| Website | TODO optional marketing URL. |
| Privacy policy URL | TODO before production submission. |
| Data safety basis | Complete from final data inventory. Current repo default is local-first with no analytics, ads, crash SDK, backend, or automatic upload. |
| App access instructions | No account is required for current V1 defaults. If a future account gate is added, provide demo access or review credentials. |

### Google Play Full Description Draft

AI Nutrition Companion is a local-first meal guidance app for deciding what to
eat next.

Use Today to review your current nutrition context, see a suggested next meal,
start a quick log, or ask the companion a practical question. Use Kitchen to
reuse common meals and ingredients. Use Me to manage goals, preferences, health
connection state, privacy boundaries, and AI provider settings.

The current V1 app keeps mock AI and local fallback nutrition behavior as the
default. No custom backend, analytics SDK, ads SDK, billing flow, or automatic
support upload is configured in this repository. User-provided provider tokens
must stay user-controlled and must not be packaged in the app.

AI Nutrition Companion gives practical nutrition guidance from the information
you provide. It does not diagnose, treat, or replace advice from a qualified
health professional.

## Screenshot Plan

Capture screenshots from a clean release-candidate build after final visual
polish. Use devices that match the current store requirements and repeat the
same flow on iOS and Android when platform-specific chrome, permissions, or
layout differ.

| Shot | Screen or state | How to reach it | Purpose |
| --- | --- | --- | --- |
| 1 | Today decision hub | Launch app, complete or use seeded onboarding, land on `Today`. | Lead with the core promise: what to eat next. |
| 2 | Suggested next meal with source cues | Today screen, scroll to the suggestion and nutrition source chips. | Show companion guidance, rationale, and provenance. |
| 3 | Daily overview and quick log | Today screen, show nutrition progress and Quick Log area. | Show low-friction tracking as decision support. |
| 4 | Photo meal logging review or fallback | From Today, open meal photo logging with mock recognition or permission fallback. | Show user-controlled photo logging and confirmation. |
| 5 | AI Companion chat | From Today chat entry, open `AI Companion` and use a suggested prompt. | Show practical AI assistance with current-day context. |
| 6 | Kitchen reuse surface | Tap `Kitchen`. | Show favorite meals, ingredient availability, and habit suggestions. |
| 7 | Me privacy and settings hub | Tap `Me`; include AI provider, credentials, health, and privacy cards when visible. | Show user control, local-first boundaries, and settings. |
| 8 | Sensitive disclosure or permission state | Trigger camera/photo, token entry, or health unavailable copy after the related issue is active. | Show privacy/safety explanation before sensitive actions. |

### Capture Notes

- Avoid screenshots containing real API tokens, signing details, personal
  email addresses, private meal photos, or health records.
- Use deterministic mock data or clearly non-sensitive seed data.
- If real provider configuration is demonstrated, use a non-secret placeholder
  state, not a real token.
- Keep status bars and system time consistent across each platform set.
- Re-capture screenshots after final app icon, display name, privacy copy,
  screenshot dimensions, and release candidate build number are confirmed.

## Review Notes Draft

Use these notes as a starting point for App Store Connect and Play Console
review fields. Update them to match final behavior before submission.

```text
AI Nutrition Companion V1 is a local-first nutrition companion for practical
meal guidance. The app helps users decide what to eat next, log meals, review
nutrition estimates, and manage goals/preferences.

Mock AI and deterministic local nutrition behavior are enabled by default for
the current V1 build. No custom backend, cloud account, analytics SDK, ads SDK,
billing flow, or automatic diagnostics upload is configured in this repository.

If provider settings are enabled, the user must provide and control their own
provider credentials. Real production API keys are not bundled in the app. Do
not enter real review secrets into screenshots or support diagnostics.

Meal photo logging is initiated only by the user. The app should request camera
or photo access only when the user starts a photo logging action, and it should
offer a local fallback or explanation if access is denied or unavailable.

Health connection behavior is currently mock/scaffolded only. The repository
does not enable HealthKit entitlements, Android Health Connect permissions, or
native health data access yet.

The app provides practical nutrition guidance. It does not diagnose, treat, or
replace advice from a qualified health professional.
```

## Pre-Submission Follow-Up

- Replace every TODO placeholder with a production-owned URL, contact, app
  record, or asset.
- Reconcile this draft with the final App Store privacy labels and Google Play
  Data safety answers.
- Update the review notes if real AI, FoodData Central, health, account,
  diagnostics, cloud sync, or support upload behavior changes.
- Verify screenshots against final app behavior, final release build number,
  and current App Store / Google Play screenshot requirements.
- Run `bash scripts/local_ci.sh` before creating a release candidate.
