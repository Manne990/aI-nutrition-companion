#!/usr/bin/env bash
set -euo pipefail

flutter pub get
bash scripts/test_release_verify.sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
