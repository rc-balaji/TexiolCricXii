# CricXii v0.3.1 Fresh Start

CricXii is Texiol's Android-first local cricket scorer. `0.3.1+11` continues the Fresh Start foundation and the account/social architecture while keeping the existing Singles scoring, gangs, player profiles, statistics, sharing and advanced PDF scorecard.

## Fresh account model

Only **Firebase Anonymous Authentication** is used by the app, silently, as the Firestore transport session. There is no Google sign-in, Facebook sign-in, Firebase Email/Password sign-in, Player-ID login, claim flow, temporary-player flow or Cloud Functions dependency.

The user-visible CricXii account uses:

- `loginCredentials/{sha256(normalizedEmail)}` — normalized login email, Player ID, password salt and password verifier. Plain-text passwords are never written.
- `players/{playerId}` — basic/public cricket profile keyed by a random eight-digit numeric Player ID.
- `sessions/{anonymousFirebaseUid}` — maps the current anonymous Firebase transport session to the CricXii Player ID.
- `accountStates/{playerId}` — private persisted cricket state for that signed-in player.

Social data is separate:

- `friendRequests/{sortedPlayerPair}`
- `notifications/{notificationId}`
- `players/{playerId}/friends/{friendPlayerId}`
- `players/{playerId}/contactFields/{field}` for optional phone, WhatsApp and location privacy.

## Registration and login

Main registration asks for name, email, password, batting style and a starting avatar. It creates the numeric Player ID and enters the app directly. The email is a login credential only; Profile Edit does not ask for it again.

Sign in uses the same email + password. Sign out and account deletion return directly to the root login screen without requiring the Android/Flutter back button.

## Add another player

Player Management, Match setup and Gang setup can create another full player account immediately. The form asks for name, login email, login password, batting style and avatar. That player can later install/open CricXii and sign in directly with those credentials. Instagram, Facebook profile URL, phone, WhatsApp, bio and other optional profile information are edited by that player later.

There is no temporary Player ID and no claim step.

## Friends and notifications

Friends use exact Player ID lookup:

`Friends -> Search Player ID -> Search Player -> Send request`

The sender immediately sees `Request sent`. Social data is synced once after account login/app restore. While the app is already open, the Notifications screen has an explicit Refresh button instead of continuous polling.

Accepting a request:

- marks the receiver's original request notification as accepted + read;
- creates the friendship on both Player IDs;
- creates a new unread `Friend request accepted` notification for the sender.

Notifications support Mark read, Mark unread, Delete, and Delete All. Deleting a still-pending incoming request rejects it first so no orphan request remains.

## Spark-first design

This build intentionally avoids Cloud Functions, Firebase Storage and provider sign-in dependencies. Firestore player lookup is exact-document lookup. Friend request refresh uses single-field queries and filters status in the app, so the supplied `firestore.indexes.json` does not require composite indexes.

Read `SECURITY-NOTE.md` before treating this custom Anonymous-only email/password layer as production authentication.

## Build

GitHub Actions expects repository secret:

`GOOGLE_SERVICES_JSON_BASE64`

The workflow generates Android shell files when needed, analyzes, runs tests and builds a release APK with:

```bash
flutter build apk --release \
  --dart-define=FIREBASE_ENABLED=${CRICXII_FIREBASE_ENABLED}
```

Before app testing, deploy the supplied Firestore rules/indexes. See `docs/FRESH_START.md` and `docs/FIREBASE_SETUP.md`.
