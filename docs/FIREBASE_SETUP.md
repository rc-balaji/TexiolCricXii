# Firebase setup

The supplied Android client configuration matches `com.texiol.crixx`. Android's `google-services.json` contains project/app identifiers used by the client SDK; it is not an Admin SDK credential and contains no service-account private key.

## Console switches

In the same Firebase project:

1. Open **Authentication → Sign-in method** and enable **Email/Password**.
2. Create **Cloud Firestore** in the region closest to the expected players.
3. Deploy `firestore.rules` and `firestore.indexes.json` with the Firebase CLI.
4. Add Android SHA-1/SHA-256 fingerprints only when Google sign-in is implemented.

Deploy rules:

```bash
firebase login
firebase use YOUR_PROJECT_ID
firebase deploy --only firestore:rules,firestore:indexes
```

## Local config

Keep the downloaded file at `firebase/google-services.json`. `tool/bootstrap_android.sh` copies it into `android/app/` and adds Google Services plugin version 4.5.0. The application initializes Firebase only when built with:

```bash
--dart-define=FIREBASE_ENABLED=true
```

Without that define, the same application remains a fully local scorer.

## GitHub Actions secret

Create a single-line base64 value without printing it into CI logs.

Linux:

```bash
base64 -w 0 firebase/google-services.json
```

macOS:

```bash
base64 -i firebase/google-services.json
```

Save the result as repository Actions secret `GOOGLE_SERVICES_JSON_BASE64`. The workflow decodes it only on the temporary runner.

## Current cloud boundary

Email/password authentication and private state recovery are implemented. Match-ID joining, cross-phone draw/scoring, Google linking, and Player-ID claiming require the Connected Singles collections described in `ARCHITECTURE.md`.

The Player-ID claim path must be handled by a callable trusted service. It verifies a one-time password/hash, claims the player document in a transaction, attaches the authenticated UID, invalidates the ticket, and returns only success/failure. Do not create a public Player-ID-to-email mapping or place an Admin SDK key in the app.
