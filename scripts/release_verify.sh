#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage:
  bash scripts/release_verify.sh [--check-only] [--android-build] [--ios-build] [--all-builds] [--skip-toolchain]

Default:
  Run deterministic release configuration checks for Android and iOS without
  requiring signing credentials, Apple team identifiers, or private profiles.

Options:
  --check-only      Validate committed release configuration and report missing
                    signing/toolchain prerequisites without running builds.
  --android-build   After checks, run `flutter build appbundle --release`.
                    Requires Android upload signing inputs outside git.
  --ios-build       After checks, run `flutter build ios --release --no-codesign`.
                    Requires macOS, Xcode, CocoaPods, and Flutter tooling.
  --all-builds      Run both optional build checks.
  --skip-toolchain  Skip Flutter/Xcode/CocoaPods command discovery. Intended for
                    deterministic script tests only.
  -h, --help        Show this help.
USAGE
}

run_android_build=false
run_ios_build=false
check_toolchain=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      ;;
    --android-build)
      run_android_build=true
      ;;
    --ios-build)
      run_ios_build=true
      ;;
    --all-builds)
      run_android_build=true
      run_ios_build=true
      ;;
    --skip-toolchain)
      check_toolchain=false
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "release_verify: unknown argument: $1" >&2
      print_usage >&2
      exit 64
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
uname_value="${GAIA_RELEASE_VERIFY_UNAME:-$(uname -s)}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*"
}

pass() {
  echo "PASS: $*"
}

require_file() {
  local path="$1"
  [[ -f "$repo_root/$path" ]] || fail "missing required file: $path"
}

require_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq "$needle" "$repo_root/$path" || fail "$path does not contain expected text: $needle"
}

require_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq "$needle" "$repo_root/$path"; then
    fail "$path contains forbidden text: $needle"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

tracked_signing_files() {
  (
    cd "$repo_root"
    git ls-files -- "android/key.properties" "android/*.jks" "android/*.keystore"
  )
}

property_file_has_key() {
  local path="$1"
  local key="$2"
  [[ -f "$path" ]] && grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$path"
}

android_signing_inputs_present() {
  local key_file="$repo_root/android/key.properties"

  if [[ -f "$key_file" ]] &&
     property_file_has_key "$key_file" "storeFile" &&
     property_file_has_key "$key_file" "storePassword" &&
     property_file_has_key "$key_file" "keyAlias" &&
     property_file_has_key "$key_file" "keyPassword"; then
    return 0
  fi

  [[ -n "${AI_NUTRITION_UPLOAD_STORE_FILE:-}" &&
     -n "${AI_NUTRITION_UPLOAD_STORE_PASSWORD:-}" &&
     -n "${AI_NUTRITION_UPLOAD_KEY_ALIAS:-}" &&
     -n "${AI_NUTRITION_UPLOAD_KEY_PASSWORD:-}" ]]
}

check_flutter_tool() {
  if [[ "$check_toolchain" == false ]]; then
    pass "Flutter toolchain check skipped by --skip-toolchain"
    return
  fi

  command_exists flutter || fail "Flutter is not on PATH. Install Flutter stable and run flutter doctor -v."
  pass "Flutter is available"
}

check_android_configuration() {
  require_file "android/app/build.gradle.kts"
  require_file "android/app/src/main/AndroidManifest.xml"
  require_file "android/app/src/main/res/values/strings.xml"
  require_file ".gitignore"

  require_contains "android/app/build.gradle.kts" 'namespace = "app.ainutrition.companion"'
  require_contains "android/app/build.gradle.kts" 'AI_NUTRITION_ANDROID_APPLICATION_ID'
  require_contains "android/app/build.gradle.kts" 'create("release")'
  require_contains "android/app/build.gradle.kts" 'signingConfigs.getByName("release")'
  require_not_contains "android/app/build.gradle.kts" 'signingConfigs.getByName("debug")'
  require_contains ".gitignore" '/android/key.properties'
  require_contains ".gitignore" '/android/*.jks'
  require_contains ".gitignore" '/android/*.keystore'

  if [[ -n "$(tracked_signing_files)" ]]; then
    fail "Android signing material is tracked by git. Remove signing files from source control."
  fi

  pass "Android release configuration: PASS"

  if android_signing_inputs_present; then
    pass "Android signing credentials: PRESENT outside committed source"
  else
    warn "Android signing credentials: MISSING. Config checks pass without secrets; --android-build needs android/key.properties, Gradle properties, or AI_NUTRITION_UPLOAD_* environment variables."
  fi
}

check_ios_configuration() {
  require_file "ios/Flutter/Release.xcconfig"
  require_file "ios/Flutter/Debug.xcconfig"
  require_file "ios/Runner.xcodeproj/project.pbxproj"
  require_file "ios/Runner/Info.plist"

  require_contains "ios/Flutter/Release.xcconfig" 'AI_NUTRITION_IOS_BUNDLE_ID=app.ainutrition.companion'
  require_contains "ios/Flutter/Release.xcconfig" 'AI_NUTRITION_IOS_DEVELOPMENT_TEAM='
  require_contains "ios/Runner.xcodeproj/project.pbxproj" 'PRODUCT_BUNDLE_IDENTIFIER = "$(AI_NUTRITION_IOS_BUNDLE_ID)"'
  require_contains "ios/Runner.xcodeproj/project.pbxproj" 'DEVELOPMENT_TEAM = "$(AI_NUTRITION_IOS_DEVELOPMENT_TEAM)"'
  require_contains "ios/Runner/Info.plist" 'AI Nutrition Companion'

  pass "iOS release configuration: PASS"

  if [[ -f "$repo_root/ios/Podfile" ]]; then
    pass "iOS CocoaPods project file: PRESENT"
  else
    warn "iOS CocoaPods project file: MISSING. iOS release builds may fail until ios/Podfile is restored or generated for plugin dependencies."
  fi

  if [[ "$uname_value" != "Darwin" ]]; then
    warn "iOS toolchain: SKIPPED on $uname_value. Xcode release build checks require macOS."
    return
  fi

  if [[ "$check_toolchain" == false ]]; then
    pass "iOS toolchain check skipped by --skip-toolchain"
    return
  fi

  command_exists xcodebuild || fail "Xcode command-line tools are missing. Install Xcode, run sudo xcode-select -s /Applications/Xcode.app, then retry."
  command_exists pod || fail "CocoaPods is missing. Install CocoaPods and run cd ios && pod install before iOS release verification."
  pass "iOS toolchain: Xcode and CocoaPods are available"
}

run_optional_android_build() {
  if ! android_signing_inputs_present; then
    fail "Cannot run Android release build: upload signing inputs are missing. Provide android/key.properties, Gradle properties, or AI_NUTRITION_UPLOAD_* environment variables outside source control."
  fi

  check_flutter_tool
  (
    cd "$repo_root"
    flutter build appbundle --release
  )
}

run_optional_ios_build() {
  [[ "$uname_value" == "Darwin" ]] || fail "Cannot run iOS release build on $uname_value. Use macOS with Xcode installed."
  [[ -f "$repo_root/ios/Podfile" ]] || fail "Cannot run iOS release build: ios/Podfile is missing. Restore the Flutter CocoaPods file, run flutter pub get, then retry."

  check_flutter_tool
  if [[ "$check_toolchain" == true ]]; then
    command_exists xcodebuild || fail "Xcode command-line tools are missing. Install Xcode and select it with xcode-select."
    command_exists pod || fail "CocoaPods is missing. Install CocoaPods and run cd ios && pod install."
  fi

  (
    cd "$repo_root"
    flutter build ios --release --no-codesign
  )
}

echo "Release verification for AI Nutrition Companion"
echo "Repository: $repo_root"

check_flutter_tool
check_android_configuration
check_ios_configuration

echo "Android build command: flutter build appbundle --release"
echo "iOS build command without private signing: flutter build ios --release --no-codesign"

if [[ "$run_android_build" == true ]]; then
  run_optional_android_build
fi

if [[ "$run_ios_build" == true ]]; then
  run_optional_ios_build
fi

pass "Release verification completed"
