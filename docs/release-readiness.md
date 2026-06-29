# AI Nutrition Companion V1 Release Readiness

Status: V1 release-readiness checklist for issue #12  
Last reviewed against platform sources: 2026-06-29

This document prepares the Flutter project for App Store and Google Play
publication work. It is not a final legal, privacy, medical, or store-review
approval. Before submission, review it against the final app behavior, final
privacy policy, production package identifiers, and current platform rules.

## Official Sources To Recheck Before Submission

- Apple App privacy details:
  https://developer.apple.com/app-store/app-privacy-details/
- Apple App Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Apple Health and Fitness:
  https://developer.apple.com/health-fitness/
- Google Play app content overview:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play User Data policy:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play health apps policy:
  https://support.google.com/googleplay/android-developer/answer/16558241
- Android Health Connect publishing guidance:
  https://developer.android.com/health-and-fitness/health-connect/publish

## Current Release Inventory

Current app facts from this repository:

- Flutter app for iOS and Android.
- Package name is still a placeholder:
  `com.example.ai_nutrition_companion`.
- Android release signing currently uses the debug signing config.
- `pubspec.yaml` version is `1.0.0+1`.
- Android currently declares `android.permission.CAMERA`.
- iOS currently declares camera and photo library usage descriptions.
- `image_picker` is present for meal photo flows.
- `shared_preferences` is present for local app state.
- No account system exists yet.
- No backend exists yet.
- User-provided AI token storage is scaffolded through
  `docs/ai-provider-settings.md` and platform secure storage.
- Health connection scaffolding exists behind a mock provider. No HealthKit
  entitlement, Android Health Connect permission, or native bridge is enabled
  yet. See `docs/health-data-scaffolding.md`.
- Local CI is `bash scripts/local_ci.sh`.

## Must Fix Before Store Submission

- Replace Android `applicationId` with the production package id.
- Replace Android debug signing with a real release signing configuration.
- Confirm iOS bundle identifier, team, signing, entitlements, and display name.
- Confirm app version and build number for each store submission.
- Provide production app icons, launch assets, and store screenshots.
- Provide final privacy policy URL before production distribution.
- Complete App Store privacy labels and Google Play Data safety form from the
  final data inventory.
- Add any required health-data, AI, photo, token, and nutrition disclaimers to
  the app UI before those features become active.
- Confirm camera/photo permission copy still matches actual behavior.
- Confirm no production secrets are committed or packaged in the app.
- Confirm provider/token behavior still matches
  `docs/ai-provider-settings.md`.
- Run the release test matrix below on physical or simulator devices.

## App Store Checklist

### App Record

- Create App Store Connect app record with the production bundle id.
- Set app name, subtitle, category, age rating, pricing, availability, and
  support URL.
- Add privacy policy URL.
- Add review notes explaining that V1 uses mock AI by default unless the user
  configures a provider later.
- If camera/photo or health flows are present, include review notes that explain
  when permissions are requested and what fallback exists if denied.

### Privacy Labels

Complete App Store privacy details from final behavior. Candidate data
categories for V1 review:

| Data area | Current or planned source | Store-review notes |
| --- | --- | --- |
| Meal photos | User-selected camera/photo logging | Declare only if photos leave the device or are retained in a way covered by Apple privacy labels. Explain processing and retention. |
| Meal history and nutrition estimates | Local logging and future AI/nutrition adapters | Treat as user content or health/fitness-adjacent data depending on final storage and transmission. |
| Goals and preferences | Onboarding and Me settings | Declare if collected, transmitted, or linked to the user. |
| Weight entries | Future #8 work | Treat as sensitive health/fitness data if stored or transmitted. |
| Health signals | Mock #11 scaffolding only | Declare health data only after actual HealthKit/Health Connect behavior exists beyond the local mock provider. |
| Chat prompts and responses | Future #9 work | Declare if sent to a provider or stored beyond local session needs. |
| User-provided AI token state | Future #13 work | Do not expose the token. Declare any token-related collection or diagnostics only if transmitted or linked. |
| Diagnostics and crash data | Not currently configured | Declare if a crash or analytics SDK is added. |

### iOS Build Direction

Local verification:

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --release
```

Archive and upload from Xcode when signing is configured:

```sh
open ios/Runner.xcworkspace
```

Before archiving:

- Confirm `PRODUCT_BUNDLE_IDENTIFIER`.
- Confirm signing team and provisioning profile.
- Confirm `CFBundleDisplayName`.
- Confirm `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`.
- Add health entitlements only when HealthKit is implemented and justified.
- Confirm App Transport Security settings if real network providers are added.

## Google Play Checklist

### App Record

- Create Play Console app record with the production package id.
- Complete App content sections, including privacy policy, Data safety,
  target audience, ads status, health content, and app access.
- Add support contact details.
- Add store listing short description, full description, screenshots, feature
  graphic, app icon, and category.
- Complete release notes for the first testing track.

### Data Safety

Complete the Data safety form from final behavior. Review these V1 data areas:

| Data area | Current or planned source | Play Console notes |
| --- | --- | --- |
| Photos and videos | Camera/photo meal logging | Declare collection/sharing if images are uploaded, retained, or processed by third parties. |
| Health and fitness | Weight, nutrition, activity, workouts, sleep | Declare health and fitness data if stored, collected, shared, or processed. |
| Personal info | Goals, preferences, dietary restrictions | Declare if collected or transmitted. |
| App activity | Meal history, chat actions, quick logs | Declare if used beyond local-only operation. |
| Messages or user content | Chat prompts/responses | Declare if sent to an AI provider or stored. |
| Device identifiers or diagnostics | Not currently configured | Declare if analytics, crash reporting, or logs are added. |
| Security practices | Future token storage | State whether data is encrypted in transit, deletion can be requested, and data collection is optional where applicable. |

### Android Build Direction

Local verification:

```sh
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Before creating an app bundle:

- Replace `com.example.ai_nutrition_companion`.
- Configure release signing outside source control.
- Confirm `minSdk`, `targetSdk`, and Play target API requirements.
- Confirm Android camera permission is requested only when the user chooses a
  camera meal-logging action.
- Add Health Connect declarations only after actual Health Connect behavior is
  implemented.
- Confirm no API keys or signing credentials are committed.

## Privacy Policy Draft Requirements

The production privacy policy must be hosted at a stable public URL and match
final app behavior. At minimum it should describe:

- What data the app processes: goals, preferences, meal logs, nutrition
  estimates, photos selected for meal logging, chat prompts/responses, weight
  entries, health signals if connected, token state, and diagnostics if added.
- Which data is local-only and which data may be sent to a provider.
- Why data is used: nutrition guidance, meal logging, personalization, AI
  provider configuration, health-context recommendations, support, and app
  reliability if diagnostics are added.
- Whether data is linked to identity. V1 currently has no accounts.
- Whether data is shared with AI, nutrition, health, analytics, crash, or cloud
  providers.
- How long data is retained locally or remotely.
- How the user can delete or reset local data.
- How the user can delete a user-provided AI token.
- How the user can disconnect health data.
- How users can contact support.
- A clear statement that the app provides practical nutrition guidance, not
  medical diagnosis or treatment.

Suggested placeholder for pre-submission docs:

```text
Privacy policy URL: TODO before production submission.
Support URL: TODO before production submission.
Data deletion request URL or support path: TODO before accounts or cloud sync.
```

## In-App Disclosure Requirements

The app should expose privacy and safety copy where the user makes a sensitive
choice, not only in the store listing.

### Nutrition And AI Disclaimer

Use concise copy in onboarding, chat safety states, and Me > Privacy:

```text
AI Nutrition Companion gives practical nutrition guidance from the information
you provide. It does not diagnose, treat, or replace advice from a qualified
health professional.
```

For high-risk or medical prompts:

```text
I cannot diagnose symptoms or provide medical treatment advice. A qualified
health professional can help with medical or eating-disorder concerns.
```

### Photo Handling

Before camera/photo permission:

```text
Use a meal photo only when you choose to log one. The app estimates foods and
portions from the selected image, then asks you to confirm or correct the meal.
```

If a real provider is added:

```text
If real AI recognition is enabled, selected meal images may be sent to the
configured provider for analysis. Do not use real provider mode for private
photos you do not want processed by that provider.
```

### Health Data

Before HealthKit or Health Connect permission:

```text
Health connection is optional. If you connect it, the app can use selected
signals such as weight, activity, workouts, or sleep to personalize suggestions.
You can disconnect it later.
```

Current V1 scaffolding uses a deterministic mock provider only. It does not add
HealthKit entitlements, Android Health Connect permissions, or native health
plugin access.

If health integration is unavailable:

```text
Health connection is not available in this build. The app still works with
manual and local nutrition data.
```

### User-Provided AI Token

Before token entry:

```text
Use your own provider token only if you understand that requests may be sent to
that provider under its terms. The app should store the token in secure local
storage when the platform supports it and should never commit or bundle real
production API keys.
```

Token deletion:

```text
Delete token removes the locally stored provider token from this device. It
does not delete data already processed by the external provider.
```

Fallback if secure storage is unavailable:

```text
Secure token storage is unavailable on this platform. Keep mock AI enabled or
enter a token only after accepting the local-storage risk.
```

## Account And Data Deletion Requirements

V1 currently has no accounts. If accounts, cloud sync, remote backups, billing,
or family/team features are introduced later:

- Add an in-app account deletion path where platform policy requires it.
- Add a hosted data deletion request path.
- Document which data is deleted immediately and which data may remain in
  backups or provider logs for a limited period.
- Update App Store privacy labels and Google Play Data safety before release.
- Revisit whether a backend is required for server-held secrets, billing,
  account deletion, rate limits, or provider terms.

## Store Listing Metadata Checklist

Prepare these assets before a production or public testing release:

- App name: `AI Nutrition Companion` or final approved name.
- Subtitle or short description focused on companion guidance, not diagnosis.
- Full description covering meal logging, nutrition suggestions, mock AI by
  default, optional provider setup, and privacy boundaries.
- Keywords or tags appropriate to nutrition, meal planning, and wellness.
- Support URL.
- Marketing URL, optional.
- Privacy policy URL.
- App icon for iOS and Android.
- iPhone screenshots for small and large devices.
- iPad screenshots if iPad is supported.
- Android phone screenshots for required Play sizes.
- Android tablet screenshots if tablet support is claimed.
- Feature graphic for Google Play.
- Demo account or review notes if a future account gate is added.
- Notes explaining mock AI, optional camera/photo use, optional health data, and
  token settings when those flows exist.

Screenshot set should cover:

- Today decision hub.
- Photo meal logging or estimate review.
- AI chat or companion answer.
- Kitchen or Quick Log.
- Me privacy/settings surface.
- Permission or sensitive-data disclosure screen when relevant.

## Release Test Matrix

Run the matrix before public testing or production submission.

| Area | iOS | Android | Expected result |
| --- | --- | --- | --- |
| Local CI | `bash scripts/local_ci.sh` | `bash scripts/local_ci.sh` | Format, analyze, and tests pass. |
| Debug launch | Simulator and physical device when available | Emulator and physical device when available | App opens to expected first-run or Today state. |
| Release build | `flutter build ios --release` | `flutter build appbundle --release` | Build completes with production identifiers and signing. |
| Small phone | iPhone SE size | 360 x 640 class emulator | Text, cards, and bottom nav do not overlap. |
| Common phone | 390 x 844 class | Pixel phone class | Primary flows remain usable. |
| Large phone | 430 x 932 class | Large Android phone class | Layout scales without oversized gaps. |
| Camera permission allowed | iOS camera/photo flow | Android camera/photo flow | Meal photo flow reaches review or fallback. |
| Camera permission denied | iOS denied state | Android denied state | App explains recovery and offers fallback. |
| Offline | Airplane mode | Airplane mode | Local/mock flows work; real providers are labeled unavailable. |
| Mock AI | Default mode | Default mode | Chat and recognition mocks remain deterministic for tests. |
| Real AI token missing | Future #13 | Future #13 | Real provider mode routes to token/settings guidance. |
| Token create/update/delete | Future #13 | Future #13 | Token state changes locally and deletion is clear. |
| Health disconnected | Me tab mock scaffold | Me tab mock scaffold | App works without health access. |
| Health denied/unavailable | Mocked provider states | Mocked provider states | App explains state and keeps manual flow available. |
| Data reset/deletion | Future settings | Future settings | User can reset supported local data and understands limits. |

## Submission Readiness Checklist

Use this as the final go/no-go list.

- [ ] Production package id and bundle id are set.
- [ ] Release signing is configured outside source control.
- [ ] Version and build number are correct.
- [ ] App icons and launch assets are final.
- [ ] App Store and Play metadata are drafted and reviewed.
- [ ] Privacy policy URL is live and matches final behavior.
- [ ] App Store privacy labels are completed from final data inventory.
- [ ] Google Play Data safety form is completed from final data inventory.
- [ ] Health content declarations are completed if health features exist.
- [ ] Camera/photo permission copy matches final behavior.
- [ ] Nutrition and AI disclaimers are visible in app and listing copy.
- [ ] Token storage and deletion disclosures are visible if token settings exist.
- [ ] Account and data deletion requirements are implemented if accounts exist.
- [ ] No production API keys, signing files, or secrets are committed.
- [ ] `bash scripts/local_ci.sh` passes.
- [ ] iOS release build completes.
- [ ] Android app bundle release build completes.
- [ ] Manual device test matrix is complete.
- [ ] Review notes explain mock AI, optional provider setup, camera/photo use,
  health-data state, and any unavailable features.

## Current V1 Gap Summary

The repository is ready for continued development, not store submission.
The largest release gaps are production identifiers, release signing, hosted
privacy/support URLs, final store metadata, final screenshots, and completed
platform privacy forms. Future issues #9, #11, and #13 must update this
document after chat, health connection, and AI token storage behavior exists.
