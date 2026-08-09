# Verification handoff

## Checks completed in this workspace

- Parsed every Dart source/test file with a prebuilt Dart tree-sitter grammar; no syntax errors were reported.
- Built the TypeScript Functions with `tsc` and ran all numeric-ID allocator tests successfully.
- Validated `firebase.json` and `firestore.indexes.json` as JSON.
- Validated `tool/bootstrap_android.sh` with `bash -n`.
- Verified the app icon is opaque and square, and all five built-in avatars are 512×512 PNG files.
- Cross-checked every declared direct dependency version against its current pub.dev package page and corrected the Firebase version set before packaging.
- Removed all user-facing legacy `TXP-...` IDs; the only remaining mention is the documented v0.1 migration.
- Kept the uploaded Firebase configuration out of the source archive; Actions consumes the encrypted repository secret.

## Flutter tests included

- Nine legal balls for the 1.5-over rule; wides do not consume a legal ball.
- Wicket-based early turn completion and Direct Runs progression.
- Completed-match undo and every requested dismissal credit.
- Runs-only ranking and full match JSON round-trip.
- Six-digit offline ID format.
- Profile/playing-style/privacy serialization.
- Public profile exclusion of sensitive contacts and private avatar URLs.

## Functions tests included

- IDs grow correctly from 6 to 7, 8, 9, and 10 digits.
- The billionth allocation is still a digits-only unique sequence value.
- Reserved allocator blocks do not overlap.

## Final CI authority

This workspace does not include Flutter, Dart, Gradle, or an Android SDK, so semantic package analysis, widget/unit execution, launcher generation, and APK compilation are delegated to `.github/workflows/android.yml`. The workflow runs `flutter analyze --no-fatal-infos`, `flutter test`, and `flutter build apk --release`, while a separate job runs `npm ci` and `npm test` for Functions.

Google sign-in requires the console/SHA setup in `FIREBASE_SETUP.md`. Facebook OAuth is implemented but remains build-credential-gated. Firestore rules should also be exercised with the Firebase Emulator Suite before a public production launch.
