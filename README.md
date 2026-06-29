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
analysis, and tests.

## Environment Variables

No environment variables are required for the default V1 local app. Nutrition
lookup uses deterministic mock/local adapters unless a real provider is wired.

The FoodData Central adapter contract reports an explicit missing-key fallback
state when `FOODDATA_CENTRAL_API_KEY` is absent. A future network-backed
implementation should read that variable outside the mobile binary and must not
ship production secrets in the app.

Future AI provider work must not hard-code production API keys in the mobile
app. User-provided tokens should be stored on device when secure platform
storage is available, and mock AI should remain the default local development
path until real provider configuration is implemented.

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
