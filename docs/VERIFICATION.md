# CricXii v0.2.2+6 verification

This package was prepared as the Spark-first test build.

## Checks completed in this package workspace

- JSON configuration files parse successfully.
- GitHub Actions YAML parses successfully.
- `tool/bootstrap_android.sh` passes `bash -n`.
- Dart source delimiter/string/comment balance scan passes for all `lib/` and `test/` files.
- Firestore Rules delimiter/string/comment balance scan passes.
- Avatar assets exist and are readable PNG images.
- App icon exists and is a readable PNG image.
- No `google-services.json`, service-account key, `.pem`, `.p12`, `.jks`, or obvious private-key/client-secret payload is bundled.
- ZIP integrity is checked after packaging.

## Checks delegated to GitHub Actions

The current workspace does not contain a Flutter/Dart SDK, so the authoritative build checks run in `.github/workflows/android.yml` after push:

1. `flutter pub get`
2. launcher icon generation
3. `flutter analyze --no-fatal-infos`
4. `flutter test`
5. release APK build

The Android workflow is Spark-first and builds with `FUNCTIONS_ENABLED=false`. The legacy `functions/` folder is retained only for a future optional backend upgrade and does not block the APK workflow.
