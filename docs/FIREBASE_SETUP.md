# Firebase setup for CricXii v0.2.2

The Android package is `com.texiol.crixx`. Keep `google-services.json` out of normal commits and provide it through the existing GitHub Actions secret.

## 1. Firebase console

1. In **Authentication → Sign-in method**, enable **Email/Password** and **Google**. Enable Facebook only after its Android/Firebase configuration is complete.
2. Add the Android SHA-1 and SHA-256 fingerprints for the signing certificate.
3. Download a fresh `google-services.json` after adding SHA fingerprints.
4. Create one Cloud Firestore database.

## 2. Spark-first deployment

For v0.2.2 testing, normal Player ID creation and social actions use Firebase Authentication + Firestore. Deploy rules and indexes:

```bash
npx --yes firebase-tools@latest login
npx --yes firebase-tools@latest deploy --project YOUR_PROJECT_ID --only "firestore:rules,firestore:indexes"
```

The Spark-first path supports:

- one Firebase account → one numeric Player ID mapping
- immediate Firestore registration for a temporary player created from another account
- Spark claim of that registered Player ID using the same authenticated email
- exact Player ID lookup
- friend request send / pending state
- incoming notifications
- accept / reject
- accepted-friend synchronization
- remove friend
- mark notification read
- one initial social sync on a fresh app session plus manual notification refresh

No continuous Firestore listener is used for this social flow.

## 3. Optional Functions compatibility

The `functions/` directory is retained for older optional backend features, especially Player-ID/password authentication. v0.2.2 no longer needs Functions for the normal temporary-player claim flow.

If the project later uses Cloud Functions, run:

```bash
cd functions
npm ci
npm test
cd ..
npx --yes firebase-tools@latest deploy --project YOUR_PROJECT_ID --only "functions"
```

The Flutter client will still work with Firestore social features when those Functions are not deployed.

## 4. Local Android config

Place the Firebase Android file at:

```text
firebase/google-services.json
```

Then run:

```bash
chmod +x tool/bootstrap_android.sh
tool/bootstrap_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter run --dart-define=FIREBASE_ENABLED=true --dart-define=FACEBOOK_ENABLED=false
```

## 5. GitHub Actions secret

Create one single-line base64 value and save it as repository secret `GOOGLE_SERVICES_JSON_BASE64`.

PowerShell:

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

## 6. Google and Facebook

Google sign-in requires the correct Android SHA fingerprints and Firebase provider configuration.

Facebook profile URLs do not require OAuth. To enable Facebook sign-in/linking, configure the Facebook developer app for `com.texiol.crixx`, enable the Firebase Facebook provider, and add repository secrets `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN`.

## Testing checklist

- Create account and complete player onboarding.
- Confirm a numeric Player ID is created.
- On another account/device, search the exact Player ID.
- Send a request and confirm the sender immediately shows **Request sent / Pending**.
- On a fresh receiver session, confirm the notification is already present.
- While the receiver app stays open, send another request and use **Notifications → Refresh** to fetch it.
- Accept/reject and refresh the sender to reconcile friendship status.
- Create a temporary player with their email and verify the full registration screen.
- Confirm that Player ID is searchable from another signed-in account. Before claim, friend request sending should explain that the Player ID is not connected to an app account yet.
- On the temporary player’s phone, register/sign in with the same email, enter the handed-off Player ID on onboarding, and confirm ownership is claimed without creating a second ID.
- Complete a match and export/share the upgraded PDF scorecard with avatars.
