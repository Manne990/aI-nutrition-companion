# AI Nutrition Companion

AI Nutrition Companion is a Flutter mobile app for iOS and Android. V1 starts
with a companion-first shell that helps answer: "What should I eat next?"

The app is not a calorie-counting clone. Tracking exists to support practical
next-meal decisions, photo logging, nutrition provenance, and AI companion
flows as the product grows.

## Requirements

- Flutter stable `3.44.4` or newer on the stable channel
- Dart SDK supplied by Flutter
- Xcode and CocoaPods for iOS simulator/device work
- Android Studio and an Android emulator or device for Android work

Check the local toolchain:

```sh
flutter doctor -v
```

## Install

```sh
flutter pub get
```

## Local Development

Run on the first available simulator, emulator, or device:

```sh
flutter run
```

Run on a specific device:

```sh
flutter devices
flutter run -d <device-id>
```

## iOS Simulator

```sh
open -a Simulator
flutter run -d ios
```

If CocoaPods state is stale after dependency changes:

```sh
cd ios
pod install
cd ..
```

## Android Emulator

Start an emulator from Android Studio or the command line, then run:

```sh
flutter devices
flutter run -d android
```

## Verification

Format, analyze, and test:

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Full local CI command:

```sh
bash scripts/local_ci.sh
```

The full local CI command runs dependency resolution, format checking, static
analysis, shell checks, and tests.

Release configuration verification:

```sh
bash scripts/release_verify.sh
```

The default release verification path checks Android and iOS release
configuration without private signing credentials. Optional release build
checks are available with `--android-build`, `--ios-build`, or `--all-builds`
when the local machine has the required signing and platform toolchains.

## Release Readiness

V1 store-preparation guidance lives in
[`docs/release-readiness.md`](docs/release-readiness.md). It tracks the
remaining App Store and Google Play work, privacy policy requirements,
nutrition/AI disclaimer placement, user-provided token disclosures, future
health-data considerations, agent-runnable release verification commands,
screenshot/metadata needs, and the pre-submission test matrix.

## Environment Variables

No environment variables are required for the default V1 local app. Nutrition
lookup uses deterministic mock/local adapters unless a real provider is wired.

Direct nutrition and auth provider architecture is documented in
[`docs/direct-api-provider-architecture.md`](docs/direct-api-provider-architecture.md).
V1 should prefer direct app integrations only when the provider contract is
public, user-owned, or explicitly client-safe; app-owned secrets require a
backend or proxy before production use.

The V1 auth boundary is documented in
[`docs/auth-provider-boundary.md`](docs/auth-provider-boundary.md). The default
implementation is mock local auth with signed-out use preserved; no Firebase,
Supabase, OAuth, or backend credential is required for local development.

The FoodData Central adapter contract reports an explicit missing-key fallback
state until a user-provided or runtime-injected API key is available. The V1
mobile boundary parses production-shaped FoodData Central search payloads behind
an injected client so tests stay deterministic and no live network call is
required for local CI. App-owned FoodData Central keys must not ship in the
mobile binary; a production app-owned key requires a future backend or proxy
that keeps the secret server-side.

AI provider calls must not hard-code production API keys in the mobile app.
User-provided tokens are stored on device when secure platform storage is
available, and mock AI remains the default local development path.

Provider/model settings and local token storage are documented in
[`docs/ai-provider-settings.md`](docs/ai-provider-settings.md). Mock AI remains
the default for tests and local CI; real provider chat calls use an injected
transport with deterministic tests and require a user-owned saved token.

## Project Structure

```text
lib/
  app/                  App shell, routing surface, and theme
  domain/               Product models and pure domain logic
  features/             User-facing screens by product area
  services/adapters/    Mock and future real provider boundaries
  shared/widgets/       Reusable UI components
test/                   Widget and domain tests
scripts/local_ci.sh     Agent-runnable local verification
.github/workflows/ci.yml
```

## Manual Runtime Verification

Automated checks cover formatting, analysis, and widget tests. Simulator/device
startup still needs a local runtime with an available iOS simulator, Android
emulator, or physical device:

```sh
flutter run -d <device-id>
```

For this bootstrap, verify that the app starts and shows the Today tab with the
AI Nutrition Companion placeholder, plus `Kitchen` and `Me` bottom navigation.
