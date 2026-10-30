#!/usr/bin/env bash
set -euo pipefail
device="emulator-5554"
test "$(adb -s "$device" shell getprop ro.kernel.qemu | tr -d '\r')" = 1
baseline_code="$(python -c "import re; from pathlib import Path; print(re.search(r'^version: .+\+(\d+)$', Path('pubspec.yaml').read_text(), re.M)[1])")"
candidate_code="$((baseline_code + 1))"
flutter build apk --debug --flavor github --target-platform android-x64 --build-number "$candidate_code"
# Android Gradle may use ANDROID_USER_HOME/XDG rather than ~/.android. Ask
# the same configuration that signed the candidate; never generate a second key.
mkdir -p .buildlog/android-update-fixtures
bash android/gradlew -p android --console=plain -q :app:signingReport > .buildlog/android-update-fixtures/signing-report.txt
fixture_keystore="$(awk '/^Variant: githubDebug$/ { selected=1 } selected && /^Store: / { sub(/^Store: /, ""); print; exit }' .buildlog/android-update-fixtures/signing-report.txt)"
test -n "$fixture_keystore" && test -f "$fixture_keystore"
python tools/android-update-fixtures.py --sdk "$ANDROID_HOME" --candidate build/app/outputs/flutter-apk/app-github-debug.apk --debug-keystore "$fixture_keystore" --baseline-version-code "$baseline_code" --output .buildlog/android-update-fixtures
flutter build apk --debug --flavor github --target-platform android-x64 --build-number "$baseline_code"
adb -s "$device" install -r build/app/outputs/flutter-apk/app-github-debug.apk
adb -s "$device" shell run-as io.github.hik4.todorbit mkdir -p files/update-fixtures
adb -s "$device" shell mkdir -p /data/local/tmp/todorbit-update-fixtures
for name in candidate.apk wrong-package.apk wrong-signer.apk wrong-abi.apk newer-sdk.apk older.apk tampered.apk candidate.json; do
  fixture=".buildlog/android-update-fixtures/$name"
  staged="/data/local/tmp/todorbit-update-fixtures/$name"
  adb -s "$device" push "$fixture" "$staged"
  adb -s "$device" shell run-as io.github.hik4.todorbit cp "$staged" "files/update-fixtures/$name"
  actual="$(adb -s "$device" shell run-as io.github.hik4.todorbit sha256sum "files/update-fixtures/$name" | tr -d '\r' | cut -d ' ' -f 1)"
  test "$actual" = "$(sha256sum "$fixture" | cut -d ' ' -f 1)"
  adb -s "$device" shell rm "$staged"
done
flutter test integration_test/android_drive_updates_test.dart --flavor github -d "$device"
