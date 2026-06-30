#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

output="$(
  cd "$repo_root"
  GAIA_RELEASE_VERIFY_UNAME=Linux bash scripts/release_verify.sh --check-only --skip-toolchain
)"

contains() {
  local needle="$1"
  if [[ "$output" != *"$needle"* ]]; then
    echo "Expected release verification output to contain: $needle" >&2
    echo "$output" >&2
    exit 1
  fi
}

contains "PASS: Android release configuration: PASS"
contains "WARN: Android signing credentials: MISSING"
contains "PASS: iOS release configuration: PASS"
contains "WARN: iOS toolchain: SKIPPED on Linux"
contains "Android build command: flutter build appbundle --release"
contains "iOS build command without private signing: flutter build ios --release --no-codesign"
contains "PASS: Release verification completed"

echo "PASS: release verification shell behavior"
