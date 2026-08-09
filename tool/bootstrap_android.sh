#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Install the stable Flutter SDK first." >&2
  exit 1
fi

if [[ ! -d android ]]; then
  flutter create \
    --platforms=android \
    --org com.texiol \
    --project-name crixx \
    .
fi

# `flutter create` adds its counter-demo widget test to an existing source
# tree. CricXii has its own tests and app root, so remove only that generated
# template before analysis.
if [[ -f test/widget_test.dart ]] && grep -q 'pumpWidget(const MyApp())' test/widget_test.dart; then
  rm -f test/widget_test.dart
fi

manifest="android/app/src/main/AndroidManifest.xml"
if [[ -f "$manifest" ]]; then
  sed -i 's/android:label="[^"]*"/android:label="CricXii"/' "$manifest"
fi

app_kts="android/app/build.gradle.kts"
app_groovy="android/app/build.gradle"
settings_kts="android/settings.gradle.kts"
settings_groovy="android/settings.gradle"

if [[ -f "$app_kts" ]]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' "$app_kts"
fi
if [[ -f "$app_groovy" ]]; then
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' "$app_groovy"
fi

mkdir -p firebase android/app
if [[ -n "${FIREBASE_CONFIG_B64:-}" ]]; then
  printf '%s' "$FIREBASE_CONFIG_B64" | base64 --decode > firebase/google-services.json
  chmod 600 firebase/google-services.json
fi

firebase_enabled=false
if [[ -f firebase/google-services.json ]]; then
  cp firebase/google-services.json android/app/google-services.json
  chmod 600 android/app/google-services.json
  firebase_enabled=true

  if [[ -f "$settings_kts" ]] && ! grep -q 'com.google.gms.google-services' "$settings_kts"; then
    sed -i '/id("com.android.application")/a\    id("com.google.gms.google-services") version "4.5.0" apply false' "$settings_kts"
  fi
  if [[ -f "$app_kts" ]] && ! grep -q 'com.google.gms.google-services' "$app_kts"; then
    sed -i '/id("com.android.application")/a\    id("com.google.gms.google-services")' "$app_kts"
  fi
  if [[ -f "$settings_groovy" ]] && ! grep -q 'com.google.gms.google-services' "$settings_groovy"; then
    sed -i "/id 'com.android.application'/a\    id 'com.google.gms.google-services' version '4.5.0' apply false" "$settings_groovy"
  fi
  if [[ -f "$app_groovy" ]] && ! grep -q 'com.google.gms.google-services' "$app_groovy"; then
    sed -i "/id 'com.android.application'/a\    id 'com.google.gms.google-services'" "$app_groovy"
  fi
fi

if [[ -f "$app_kts" ]] && ! grep -q 'applicationId = "com.texiol.crixx"' "$app_kts"; then
  echo "Unexpected Android application ID. Expected com.texiol.crixx." >&2
  exit 1
fi
if [[ -f "$app_groovy" ]] && ! grep -q "applicationId 'com.texiol.crixx'" "$app_groovy"; then
  echo "Unexpected Android application ID. Expected com.texiol.crixx." >&2
  exit 1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'CRICXII_FIREBASE_ENABLED=%s\n' "$firebase_enabled" >> "$GITHUB_ENV"
fi

echo "Android shell ready: com.texiol.crixx (Firebase: $firebase_enabled)"
