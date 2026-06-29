# AI Nutrition Companion V1 UX Foundation

Status: V1 foundation for issues #1-#14  
Primary artifact for: #14, V1-00 Define UX foundation, screen map, and interaction principles

## 1. Purpose

AI Nutrition Companion V1 helps the user decide what to eat next with as little manual effort as possible. It is a companion, not a tracker. Tracking exists only to support better decisions.

The primary user promise is:

> Help me decide what to eat next.

The V1 UX should make the next useful action obvious:

- accept a suggested meal
- change or defer the suggestion
- log what the user actually ate
- ask the companion a practical nutrition question
- adjust goals, preferences, health connection, or AI provider settings

## 2. Source Hierarchy

Use this order when a later V1 issue needs to resolve a UX question:

1. Product vision in `projects/aI-nutrition-companion/vision.md`
2. V1 product scope in `projects/aI-nutrition-companion/v1-product-scope.md`
3. Concept images `Design1.png`, `Design2.png`, and `Design3.png`
4. GitHub V1 issues #1-#14
5. Citizen design judgment inside the autonomy boundary in this document

If these sources conflict, preserve the product promise first: practical companion guidance with low friction.

Store-publication direction was checked on 2026-06-29 against:

- Apple App Store privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Google Play user data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Android Health Connect publishing guidance: https://developer.android.com/health-and-fitness/health-connect/publish
- Google Play health content and services policy: https://support.google.com/googleplay/android-developer/answer/16679511

These sources support the V1 UX requirement that privacy, user data, photo, health, AI-token, and in-app disclosure copy must be explicit and reachable before store submission. This document does not replace a final legal, platform-policy, or store-review pass.

## 3. Concept-Derived Decisions

The supplied concept images are partial Today-screen concepts, not complete app designs. They establish the visual and interaction direction below.

### Visual Direction

- Warm ivory app background.
- Deep green primary surfaces and primary actions.
- Peach accent for "now", selected, AI-suggested, and positive emphasis.
- Large, calm typography with strong hierarchy.
- Soft rounded cards, chips, and pill controls.
- Food photography or realistic food imagery as the main visual asset for meal suggestions.
- Bottom navigation with `Today`, `Kitchen`, and `Me`.
- Sparse, editorial composition rather than dense dashboard layout.

### Interaction Direction

- Suggested next meal is the primary object on Today.
- The app explains why a suggestion is useful in plain language.
- User actions are direct: accept, change, defer.
- AI insight appears as a small companion message with action chips.
- Quick Log appears as a low-friction habit-detected section.
- Chat entry is always nearby, with text primary and camera/voice entry points visible.

## 4. Citizen-Proposed Foundation Decisions

These decisions extend the concepts to cover the full V1 scope.

- `Today` is the decision hub and daily overview surface.
- `Kitchen` is the reusable-food and habit surface.
- `Me` is the personal configuration, progress detail, permissions, privacy, and provider-settings surface.
- Photo logging can start from Today, Chat camera, Kitchen reusable foods, or Quick Log correction, but all paths converge on one estimate-review-and-correct flow.
- Weight tracking is visible on Today as a compact decision-support signal and editable in Me as a detail surface.
- Privacy, AI, nutrition disclaimer, token storage disclosure, and health connection status are all reachable from Me and shown contextually before sensitive features are used.
- Mock AI, mock health data, and local fallback nutrition data are valid V1 states. The UX must not require a production backend.

## 5. Product Experience Principles

### Companion, Not Tracker

Lead with guidance, not reports. Numbers should answer "what does this mean for my next choice?"

Use:

- "You're low on protein today. A skyr bowl would close most of the gap."
- "This estimate is uncertain. Confirm the portion before saving."

Avoid:

- "You consumed 742 kcal."
- "Macro distribution: 29/42/29."

### Low Friction First

Prefer camera, history, defaults, and one-tap confirmation before manual entry. Manual correction must be available, but it should not be the primary path.

### Honest AI

AI estimates are helpful guesses until confirmed or enriched by nutrition data. The UI must distinguish:

- AI-estimated
- user-confirmed
- database-verified
- fallback/local
- unavailable

### Safe Practicality

The companion can provide practical nutrition guidance. It must not diagnose, treat medical conditions, or imply certainty where the data is incomplete.

## 6. Information Architecture

### Top-Level Tabs

| Tab | Role | Primary Question | V1 Content |
| --- | --- | --- | --- |
| Today | Decision hub | What should I eat next? | Suggested next meal, daily rhythm, quick log, daily overview, AI insight, chat entry |
| Kitchen | Reuse and reduce effort | What do I usually eat or have available? | Favorite meals, common ingredients, habit suggestions, reusable quick-log items |
| Me | Personal setup and control | What does the app know and use? | Goals, preferences, weight detail, health connection, AI provider/model/token settings, privacy/disclaimers |

### Navigation Rules

- Keep only three bottom-nav destinations in V1: `Today`, `Kitchen`, `Me`.
- Do not add new top-level tabs without escalation.
- Use modal sheets for short tasks: confirm quick-log item, adjust portion, explain nutrition source, delete token.
- Use full screens for focused or sensitive flows: onboarding, photo review, chat, AI settings, health connection, privacy/disclaimer.
- A system back action should never discard user-entered corrections without confirmation.

## 7. V1 Screen Map

### App Shell And First Run

| Screen | Location | Purpose | Source |
| --- | --- | --- | --- |
| App shell | Root | Hosts bottom navigation and global loading/offline banners | V1 scope, #1 |
| First-run gate | Root | Sends new users to onboarding and returning users to Today | V1 scope, #4 |
| Onboarding welcome and boundaries | Full screen | Set companion promise and show privacy/AI/nutrition boundaries | Vision, V1 scope, #4, #12 |
| Goal setup | Onboarding | Capture primary nutrition/weight goal | V1 scope, #4 |
| Food constraints | Onboarding | Capture dietary preferences, allergies, intolerances, disliked foods | V1 scope, #4 |
| Protein and weight basics | Onboarding | Capture protein target and optional weight goal baseline | V1 scope, #4, #8 |
| Coaching tone | Onboarding | Capture preferred style of companion language | V1 scope, #4 |
| Optional permissions preview | Onboarding | Explain camera, AI, and health permissions without requesting too early | V1 scope, #4, #11, #12 |

### Today

| Screen/Region | Location | Purpose | Source |
| --- | --- | --- | --- |
| Today home | Today tab | Answer "what should I eat next?" | Vision, V1 scope, concepts, #3 |
| Rhythm strip | Today home | Show current moment and time since last meal | Concepts, #3 |
| Suggested next meal card | Today home | Show recommended meal, rationale, image, chips, actions | Concepts, #3 |
| AI insight card | Today home | Offer contextual companion note and choices | Concepts, #3, #9 |
| Quick Log preview | Today home | One-tap habit suggestions | Concepts, V1 scope, #10 |
| Daily overview summary | Today home | Show protein, calories, macros, logged meals, weight signal | V1 scope, #8 |
| Chat composer entry | Today home | Start practical AI chat with text, camera, and voice entry points | Concepts, #9 |

### Meal Logging

| Screen | Location | Purpose | Source |
| --- | --- | --- | --- |
| Log meal entry sheet | Today or Kitchen | Choose camera, photo library, quick item, or manual fallback | V1 scope, #6, #10 |
| Camera/photo permission state | Full screen/sheet | Explain permission denied, unavailable, or retry path | V1 scope, #6, #12 |
| Photo analyzing state | Full screen | Show progress while mock/real AI recognition runs | V1 scope, #6 |
| Meal estimate review | Full screen | Show recognized foods, portions, confidence, macros, source states | V1 scope, #5, #6, #7 |
| Correction editor | Sheet/full screen | Edit item name, amount, portion, remove/add item | V1 scope, #6 |
| Save confirmation | Sheet | Confirm meal saved and update Today overview | V1 scope, #6, #8 |
| Nutrition source details | Sheet | Explain AI estimate, user confirmation, database verification, fallback | V1 scope, #5, #7 |

### AI Companion

| Screen | Location | Purpose | Source |
| --- | --- | --- | --- |
| Chat thread | Full screen from Today | Ask practical nutrition questions using today context | Vision, V1 scope, #9 |
| Chat response loading | Chat | Show model/provider activity without exposing internals | V1 scope, #9, #13 |
| Chat safety boundary response | Chat | Decline diagnosis/unsafe claims and redirect to professional advice | V1 scope, #9, #12 |
| Chat adapter error state | Chat | Show retry, use mock mode, or check provider settings | V1 scope, #9, #13 |

### Kitchen

| Screen/Region | Location | Purpose | Source |
| --- | --- | --- | --- |
| Kitchen home | Kitchen tab | Show favorites, common meals, ingredients, and habit suggestions | V1 scope, #10 |
| Favorite meal detail | Kitchen | Review reusable meal and log with one tap | V1 scope, #10 |
| Common ingredient detail | Kitchen | Show availability placeholder and related quick meals | V1 scope, #10 |
| Quick Log item confirm | Sheet | Confirm habit-detected item and create meal/snack record | Concepts, V1 scope, #10 |
| Empty Kitchen | Kitchen tab | Explain that favorites appear after logging meals | V1 scope, #10 |

### Me

| Screen | Location | Purpose | Source |
| --- | --- | --- | --- |
| Me home | Me tab | Hub for goals, preferences, weight, health, AI, privacy | V1 scope, #4, #8, #11, #12, #13 |
| Goals and preferences | Me | Edit onboarding choices | V1 scope, #4 |
| Weight tracking detail | Me | Add/edit weight entries and view simple trend | V1 scope, #8 |
| Health connection | Me | Connect, disconnect, or view denied/unavailable state | V1 scope, #11 |
| AI provider settings | Me | Choose mock/real provider, model, and token state | V1 scope, #13 |
| Token entry/delete | Me | Enter, update, or delete local user-provided API token | V1 scope, #13 |
| Privacy and disclaimers | Me | Show nutrition, AI, photo, health, and token disclosures | V1 scope, #4, #12, #13 |
| Release readiness links | Me/docs only | Surface copy requirements when app store work begins | V1 scope, #12 |

## 8. Primary User Flows

### 8.1 First-Run Onboarding

1. User opens app.
2. First-run gate shows onboarding welcome.
3. App states the promise: it helps decide what to eat next.
4. User accepts privacy, AI, and nutrition boundaries.
5. User selects primary goal.
6. User enters dietary preferences, allergies/intolerances, and disliked foods.
7. User sets basic protein and optional weight goal.
8. User selects coaching tone.
9. App previews optional permissions and explains they are requested only when needed.
10. User lands on Today with a suggestion generated from seed/default context.

States:

- Empty: no preferences yet, show skip-safe defaults.
- Loading: restoring onboarding state.
- Error: local persistence unavailable, allow retry and continue with temporary session.
- Offline: onboarding can proceed with local defaults; real provider setup can wait.

### 8.2 Photo Meal Logging And Correction

1. User taps Quick Log, camera, or meal logging action.
2. App asks for camera/photo permission only at that moment.
3. User captures or selects a photo.
4. App shows analyzing state using mock or configured AI adapter.
5. Meal estimate review shows foods, portions, confidence, calories, protein, carbs, fat, and source labels.
6. User corrects food names, portions, or items.
7. Totals update before save.
8. User saves confirmed meal.
9. Today daily overview, rhythm, Quick Log history, and Kitchen history update.

States:

- Empty: no photo selected, offer camera/gallery and quick-log alternatives.
- Loading: analyzing photo or enriching nutrition facts.
- Error: AI adapter failed, allow retry, mock fallback, or manual quick-log fallback.
- Offline: permit mock/local fallback if available; do not claim database verification.
- Permission denied: explain setting path and offer gallery/manual fallback.

### 8.3 AI Chat Entry And Response

1. User enters text from Today composer or opens full chat.
2. User may use camera shortcut to start photo logging or attach context.
3. Voice button is visible as a V1 placeholder if voice is not implemented yet.
4. App builds context from goals, preferences, logged meals, current suggestion, and selected provider/model state.
5. Mock AI responds deterministically by default.
6. Real provider mode uses configured provider/model and local token when available.
7. Response includes practical advice, uncertainty, and safe boundaries.
8. User can ask a follow-up, accept suggested action, or jump to logging/settings.

States:

- Empty: suggested prompt chips such as "What should I eat next?" and "How can I hit protein today?"
- Loading: companion is thinking, with cancel/back available.
- Error: show provider/token issue and route to AI settings.
- Offline: mock responses can work; real provider responses show offline limitation.
- Safety boundary: refuse diagnosis or unsafe medical claims and suggest professional care.

### 8.4 AI Provider, Model, And Token Settings

1. User opens Me.
2. User opens AI provider settings.
3. User sees current mode: mock AI or real provider.
4. User selects provider and model.
5. User enters token into secure local storage when supported.
6. App shows token saved state without revealing the token.
7. User can update or delete token.
8. Chat and meal recognition adapters read selected provider/model configuration.

States:

- Empty: mock AI selected, no token needed.
- Loading: reading secure-storage state.
- Error: secure storage unavailable, explain fallback and keep mock as default.
- Offline: settings can be edited locally; provider validation waits.
- Token missing: provider selected but unavailable until token is entered.

### 8.5 Health Permission And Disconnected States

1. User sees optional health prompt in Me or contextual Today insight.
2. App explains why weight/activity/workout/sleep signals can improve suggestions.
3. User chooses connect, not now, or learn more.
4. App requests platform permission only after connect intent.
5. Health connection screen shows connected, disconnected, denied, unavailable, or mock state.
6. User can disconnect later.

States:

- Disconnected: app works with manual/local data.
- Denied: show how to change permission and keep app usable.
- Unavailable: show platform support gap.
- Loading: checking platform provider.
- Error: provider failed; use mock/local fallback for tests.

### 8.6 Daily Overview And Weight Tracking

1. Today shows compact daily overview under companion content.
2. Protein progress is most prominent among numeric metrics.
3. Calories, carbs, and fat are secondary and framed as decision support.
4. Logged meals are listed with source/provenance labels.
5. Weight appears as a compact trend or last-entry signal when available.
6. User taps weight signal to open Me weight detail and add/edit entries.

States:

- Empty day: suggest logging or accepting the next meal, not a blank dashboard.
- Partial day: show current gaps and next useful action.
- Completed day: summarize progress and suggest tomorrow prep if useful.
- Missing weight: invite optional entry without blocking recommendations.

### 8.7 Kitchen And Quick Log

1. Today Quick Log shows habit-detected foods for the current time window.
2. User confirms a suggestion in one tap or opens item detail.
3. Confirmed item creates a meal/snack with provenance.
4. Kitchen shows favorites, common meals, and ingredient availability placeholders.
5. Kitchen improves as meal history grows.

States:

- Empty Kitchen: "Favorites appear after you log meals."
- No habit match: show common defaults and camera/log action.
- Loading: calculating deterministic habit suggestions.
- Error: use static fallback suggestions.
- Offline: local history still works.

### 8.8 Privacy And Disclaimer Placement

Privacy and safety copy must be visible where it affects consent:

- Onboarding: before AI nutrition guidance is used.
- Photo logging: before camera/photo permission and image handling.
- Health connection: before platform health permission.
- AI provider settings: before token entry and deletion.
- Chat safety: when the user asks medical or high-risk questions.
- Me > Privacy and disclaimers: always available as a durable reference.

Store-facing disclosure inventory for later #12 work:

- Data categories collected or processed: meal photos, meal history, nutrition estimates, goals/preferences, weight entries, health signals if connected, chat prompts/responses, and user-provided AI token state.
- Data purposes: nutrition guidance, meal logging, personalization, provider configuration, local app operation, and optional health-based recommendation context.
- User controls: delete token, disconnect health source, edit preferences, correct meal estimates, and reset local data where supported.
- Disclosure surfaces: onboarding, feature permission explainers, Me privacy/disclaimer screen, AI provider settings, and store metadata/checklists.

## 9. Empty, Loading, Error, And Offline Rules

Every V1 screen should define the closest useful fallback.

| State | UX Rule |
| --- | --- |
| Empty | Explain what will appear and offer the next low-friction action. |
| Loading | Name the operation in user terms, not implementation terms. |
| Error | State what failed, preserve user input, offer retry or fallback. |
| Offline | Keep local/mock flows working where possible and label unavailable real-provider features. |
| Permission denied | Explain why permission helps, how to change it, and what can still be done. |
| Unavailable | Be explicit when a platform feature is not supported in the current environment. |

No state should be a dead end.

## 10. Tone Of Voice

The companion should sound practical, calm, and specific.

Rules:

- Prefer one actionable sentence over multiple abstract explanations.
- Use "you" and "today" when context is available.
- Show uncertainty plainly: "This looks like..." or "The portion estimate is uncertain."
- Suggest concrete foods or actions.
- Avoid shame, judgment, streak pressure, and guilt.
- Avoid clinical diagnosis or treatment language.
- Avoid calorie-counting as the primary framing.
- Keep button labels short and human: `Sounds perfect`, `Change it`, `Not now`, `Save meal`, `Adjust portion`.

Examples:

- "A protein-forward snack would help more than another coffee right now."
- "I can use your usual breakfast as a quick log. Check the portion first?"
- "I cannot diagnose symptoms. For medical advice, talk with a qualified professional."

## 11. Component Inventory

V1 design-system work should provide reusable Flutter components for:

- App shell and bottom navigation.
- Screen header with date/context and day focus.
- Rhythm strip/timeline.
- Suggested meal card with image, title, rationale, chips, and actions.
- Primary, secondary, tertiary, destructive, and icon buttons.
- Soft chips for nutrition rationale, prep time, ingredient availability, confidence, and source.
- AI insight card/message bubble with companion avatar/label.
- Chat composer with text field, camera button, and voice button.
- Chat thread bubbles and safety response panel.
- Quick Log dark surface with horizontal item selector.
- Favorite meal and ingredient cards.
- Daily overview metric row/card.
- Protein progress indicator.
- Weight trend compact card.
- Meal history row with source labels.
- Photo analysis loading panel.
- Meal estimate item row and correction editor.
- Permission explainer panel.
- Settings list item and sensitive token field.
- Empty/error/offline state panels.
- Disclaimer callout.

## 12. Design Token Starting Point

These tokens are a starting point for #2 and should be refined in Flutter while preserving the concept direction.

### Color

| Token | Suggested Value | Use |
| --- | --- | --- |
| `color.background.ivory` | `#F6F0E4` | App background |
| `color.surface.warm` | `#FFFDF7` | Cards and sheets |
| `color.surface.muted` | `#ECE8DA` | Secondary chips and nav container |
| `color.primary.green` | `#2F6F55` | Primary actions and selected nav |
| `color.primary.deep` | `#142D23` | Dark Quick Log surface and strong text |
| `color.accent.peach` | `#F28B61` | Now marker, selected quick item, AI suggestion accents |
| `color.text.primary` | `#172820` | Main text |
| `color.text.secondary` | `#59635C` | Body and helper text |
| `color.border.soft` | `#E4DDCF` | Card borders |
| `color.status.warning` | `#B56A2E` | Caution and unverified labels |
| `color.status.error` | `#A33A32` | Errors and destructive action |

### Typography

- Font family: use platform default or a high-quality sans-serif until brand typography is selected.
- Display: 32/38, weight 700, for Today focus and major meal titles.
- Title: 24/30, weight 650, for screen sections.
- Body: 17/26, weight 400, for explanations.
- Body strong: 17/24, weight 600, for card labels.
- Caption: 13/18, weight 600, uppercase only for short labels like `HABIT DETECTED`.
- Do not scale font size with viewport width. Respect platform text scaling.

### Spacing, Radius, And Elevation

| Token | Value | Use |
| --- | --- | --- |
| `space.1` | 4 | Tight internal gaps |
| `space.2` | 8 | Chip and row gaps |
| `space.3` | 12 | Compact card padding |
| `space.4` | 16 | Default horizontal rhythm |
| `space.5` | 24 | Section spacing |
| `space.6` | 32 | Large section spacing |
| `radius.chip` | 999 | Pills and chips |
| `radius.card` | 28 | Large cards from concepts |
| `radius.sheet` | 32 | Modal sheets |
| `radius.image` | 24 | Food images |
| `elevation.card` | subtle shadow | Large surface separation only |
| `elevation.nav` | soft shadow | Floating bottom nav |

Keep shadows soft and sparse. Most hierarchy should come from spacing, color, and type.

## 13. Accessibility And Phone-Size Expectations

### Accessibility

- Minimum touch target: 44 x 44 dp; prefer 48 x 48 dp for primary controls.
- All icon-only buttons need semantic labels.
- Text and controls must meet WCAG AA contrast where practical for mobile UI.
- Do not encode status by color alone; pair with labels or icons.
- Respect platform text scaling. Long labels wrap or truncate intentionally, never overlap.
- Photo and meal images need semantic descriptions when they carry meaning.
- Chat and loading states should announce important changes to screen readers.

### Phone Sizes

Design for:

- Small phones around 360 x 640 logical pixels.
- Common phones around 390 x 844.
- Large phones around 430 x 932.

Expectations:

- Bottom navigation remains reachable and does not overlap primary content.
- Cards may stack vertically; do not use side-by-side layouts for critical actions on small phones.
- Suggested meal card image keeps a stable aspect ratio.
- Horizontal Quick Log can scroll; item labels must remain readable.
- Primary actions stay visible without requiring precision taps.

## 14. No-Backend V1 Boundary

No V1 screen may require unavailable backend functionality.

Allowed V1 dependencies:

- local persistence
- deterministic mock AI
- direct provider adapters when user config exists
- secure local token storage or documented fallback
- local fallback food data
- public nutrition providers behind configuration
- mock health provider

Escalate before adding a backend for:

- server-held secrets
- account sync
- billing
- shared family/team data
- rate limiting or provider contracts that prohibit direct app calls
- production analytics tied to personal health/nutrition data

## 15. Issue Coverage Matrix

| GitHub Issue | UX Coverage In This Document |
| --- | --- |
| #1 V1-01 Bootstrap Flutter mobile app, CI, and repository workflow | App shell, first-run gate, bottom navigation, no feature logic requirement |
| #2 V1-02 Implement the Flutter design system from the reference concepts | Concept-derived decisions, component inventory, design tokens, accessibility and phone-size expectations |
| #3 V1-03 Build the Today screen with suggested-next-meal decision support | Today IA, rhythm strip, suggested meal card, actions, AI insight, daily decision hub |
| #4 V1-04 Add onboarding for goals, preferences, and consent boundaries | Onboarding screen map, onboarding flow, privacy/disclaimer placement |
| #5 V1-05 Define Dart nutrition domain model, local persistence, and seed data | Provenance labels, daily overview, meal history, local persistence expectations |
| #6 V1-06 Build photo-based meal logging with AI recognition adapter contract | Photo logging, analyzing, estimate review, correction editor, permission/error states |
| #7 V1-07 Add nutrition lookup adapters and verified macro calculation | Nutrition source details, source labels, fallback states, no unverified AI fact claims |
| #8 V1-08 Build daily nutrition overview, protein tracking, and weight tracking | Daily overview placement, protein priority, weight signal on Today, detail in Me |
| #9 V1-09 Build AI Companion chat with camera and voice entry points | Chat composer, chat thread, camera/voice entry points, response states, safety boundaries |
| #10 V1-10 Build Kitchen and Quick Log habit suggestions | Kitchen IA, Quick Log behavior, favorite/common meal surfaces, empty states |
| #11 V1-11 Add HealthKit and Health Connect permission scaffolding | Health connection screen, permission timing, disconnected/denied/unavailable states |
| #12 V1-12 Prepare App Store and Google Play release readiness | Privacy/disclaimer placement, health/photo/token disclosures, release-readiness touchpoints |
| #13 V1-13 Configure AI provider, model selection, and secure local token storage | AI provider settings, token entry/delete, mock default, provider error/offline states |
| #14 V1-00 Define UX foundation, screen map, and interaction principles | This UX foundation document and verification matrices |

## 16. Screen And Flow Source Coverage Matrix

| UX Area | Vision | V1 Scope | Concepts | Issues |
| --- | --- | --- | --- | --- |
| Companion promise and low-friction principle | Yes | Yes | Implied | #3, #9, #14 |
| Today decision hub | Yes | Yes | Yes | #3, #8 |
| Bottom nav: Today, Kitchen, Me | No | Yes | Yes | #2, #3, #10, #14 |
| Onboarding | Yes | Yes | No | #4 |
| Photo meal logging and correction | Yes | Yes | No | #5, #6, #7 |
| Nutrition provenance | Yes | Yes | No | #5, #6, #7 |
| Daily overview and weight tracking | Yes | Yes | Partial | #8 |
| AI chat | Yes | Yes | Yes | #9, #13 |
| Kitchen and Quick Log | Yes | Yes | Yes | #10 |
| Health permission states | Yes | Yes | Partial | #11, #12 |
| AI provider/model/token settings | Yes | Yes | No | #13 |
| Privacy and disclaimers | Yes | Yes | No | #4, #11, #12, #13 |
| Empty/loading/error/offline states | No | Yes | Partial | #3, #6, #9, #10, #11, #13, #14 |
| Design tokens and components | No | Yes | Yes | #2, #14 |

## 17. Future UX Decision Boundaries

Citizens may decide independently:

- Layout details inside the established purpose of a screen.
- Copy improvements that preserve companion tone and safety posture.
- Component variants that reuse shared tokens.
- Empty, loading, error, and offline wording.
- Minor interaction details that reduce friction.
- Fixture/demo content needed for deterministic tests.

Citizens must escalate before implementing:

- New top-level navigation sections.
- Major changes to the product promise.
- Visual styles unrelated to the concepts.
- New data collection beyond V1 scope.
- Nutrition or medical claims that change safety posture.
- Backend requirements that conflict with the minimal-backend principle.
- App Store or Google Play privacy posture changes.
- Any flow that hides AI uncertainty, token storage, health data use, or nutrition provenance.

## 18. Verification Notes For This Document

This document is documentation-only. Flutter commands are not required unless Flutter files are introduced.

Verification performed by the author should confirm:

- Every GitHub V1 issue #1-#14 is covered in the issue coverage matrix.
- Every planned screen or region has a source in the vision, V1 scope, concept direction, or issue set.
- Primary flows include empty, loading, error, offline, permission, or disconnected states where applicable.
- No V1 screen requires unavailable backend functionality.
- V1-02 and later UI issues can build screens without inventing a new top-level IA or visual style.
