# Firebase setup for CricXii v0.2

The Android package is `com.texiol.crixx`. `google-services.json` is an Android client configuration file, not an Admin service-account key. Keep it out of normal commits and deliver it through the existing GitHub Actions secret.

## 1. Firebase console

1. In **Authentication → Sign-in method**, enable **Email/Password**, **Google**, and **Anonymous**. Anonymous auth is used only while securely claiming a provisional player. Enable **Facebook** after completing section 5.
2. In **Project settings → Your apps → Android**, add the SHA-1 and SHA-256 fingerprints for the signing certificate.
3. Download a fresh `google-services.json` after adding SHA fingerprints. A file whose `oauth_client` list is empty will not complete Android Google sign-in.
4. Create Cloud Firestore. CricXii Functions and the Flutter client use region `asia-south1`; choose compatible locations before production data exists.
5. Upgrade the Firebase project to the Blaze pay-as-you-go plan before deploying Cloud Functions. The app still builds and scores locally without that upgrade, but secure global Player IDs and cross-phone social actions require the Functions.

## 2. Deploy backend and rules

Install the Firebase CLI, sign in, select the same project, then run:

```bash
cd functions
npm ci
npm test
cd ..
firebase login
firebase use YOUR_PROJECT_ID
firebase deploy --only functions,firestore:rules,firestore:indexes
```

The deployment includes numeric-ID allocation, Player-ID login/password change, provisional creation/edit/claim/deletion, friend requests, notification updates, full social/stat reset, and account-data deletion.

## 3. Local Android config

Place the downloaded file at:

```text
firebase/google-services.json
```

Then run:

```bash
tool/bootstrap_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter run --dart-define=FIREBASE_ENABLED=true --dart-define=FACEBOOK_ENABLED=false
```

App Check code is included but disabled in the supplied workflow. After registering the Android app with Play Integrity and validating metrics, build with `APP_CHECK_ENABLED=true` and then enable enforcement in the console.

## 4. GitHub Actions secret

Create one single-line base64 value and save it as repository secret `GOOGLE_SERVICES_JSON_BASE64`.

PowerShell (copies the value to the clipboard and also writes a reviewable text file):

```powershell
$value = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path ".\google-services.json")))
$value | Set-Content -NoNewline ".\google-services-base64.txt"
$value | Set-Clipboard
```

Linux:

```bash
base64 -w 0 firebase/google-services.json
```

macOS:

```bash
base64 -i firebase/google-services.json
```

The GitHub workflow decodes it only on its temporary runner. If the secret is absent, it produces an offline-capable APK.

## 5. Google account linking

The client implementation supports sign-in, link, change, and disconnect. Google must be enabled in Firebase and the current signing SHA-1 must exist in the Android app registration. A provider already attached to another Firebase UID is rejected instead of silently moving data.

## 6. Facebook sign-in/linking

Facebook profile URLs work without OAuth. To activate Facebook sign-in, linking, account replacement, profile-photo capture, and disconnection:

1. Create/configure the Facebook developer app for Android package `com.texiol.crixx` and activity `com.texiol.crixx.MainActivity`.
2. Register the CI/release key hashes in the Facebook app.
3. Enable Facebook in Firebase Authentication using the Facebook App ID and App Secret.
4. Add repository Actions secrets `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN`.
5. Re-run the Android workflow. It writes the native Android resources only on the temporary runner and sets `FACEBOOK_ENABLED=true`.

For a local build, export both `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` before running `tool/bootstrap_android.sh`, then pass `--dart-define=FACEBOOK_ENABLED=true`. If either build credential is missing, the SDK still builds with inert placeholders and the Facebook login controls stay disabled.

## Production checklist

- Test email, Google, Facebook, Player-ID, provisional claim, disconnect, and deletion on a physical device.
- Register release-signing SHA-1/SHA-256, not only debug fingerprints.
- Enable App Check only after the release build is registered and monitored.
- Configure Firestore TTL for expired `loginRateLimits.resetAt` documents.
- Review Firebase/Functions usage and budget alerts before public release.
