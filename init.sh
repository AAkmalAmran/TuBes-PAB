#!/usr/bin/env bash
# Standard startup and verification path for FinQuest (Flutter).
# Run from the repository root: ./init.sh
# On Windows, run it from Git Bash or WSL, or run the three flutter commands below manually.

set -euo pipefail

echo "Working directory: $(pwd)"

if [ ! -f "pubspec.yaml" ]; then
  echo "ERROR: pubspec.yaml not found. Run this script from the Flutter project root." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter is not on PATH. Install the Flutter SDK or fix PATH first." >&2
  exit 1
fi

echo "== flutter pub get =="
flutter pub get

echo "== flutter analyze =="
flutter analyze

echo "== flutter test =="
if [ -d "test" ]; then
  flutter test
else
  echo "No test directory yet; skipping flutter test."
fi

echo "Baseline verification passed."
echo "Reminder: record manual emulator verification in claude-progress.md or feature_list.json."
