# CricXii

CricXii is Texiol's Android-first scorer for real local cricket. Version `0.2.0+3` keeps the working Singles match engine and adds the Player & Social foundation: independent accounts, numeric Player IDs, provisional players, profiles, privacy, friends, notifications, and original CricXii branding.

## Included in v0.2

- Globally allocated numeric Player IDs beginning at `100000`; digit length grows naturally after each numeric range is exhausted.
- Server-side ID blocks plus an atomic `playerIds/{id}.create()` guard, so allocation does not scan the player collection.
- One Firebase UID owns one player. Other players on a phone are cached opponents, never switchable subprofiles.
- Existing v0.1 `TXP-...` local IDs migrate to deterministic six-digit local IDs without breaking gangs, matches, events, batting order, friends, or history.
- Provisional no-phone registration with a temporary numeric password and secure later claim; it remains the initial Player-ID login until changed.
- Email/password, Player ID/password, Google, and credential-gated Facebook authentication; connection, replacement, disconnection, reset, sign-out, and account deletion controls.
- Friend request, accept/reject, in-app notification, player lookup, and fixed-height searchable player/friend lists.
- Editable profile with right/left batting, multiple/custom bowling styles, DOB-derived age, bio, place, social links, five original avatars, provider photos, and named private HTTPS avatars with generated IDs.
- Per-field privacy for email, phone, WhatsApp, and place: only me, all friends, selected friends, everyone except selected, or everyone.
- Separate Singles and future Team statistics/history sections.
- Existing Singles scoring: 6/9/12/18/36/custom balls, secret draw, optional ball tracker, direct totals, dismissals, undo/reset, points/runs rankings, history, and PDF scorecard sharing.
- GitHub Actions checks Functions, analyzes/tests Flutter, generates the launcher icon, and builds a release APK.

Team-match scoring and multi-phone live match scoring remain future phases. Facebook profile links work immediately; Facebook OAuth automatically activates in builds that receive a Facebook App ID and Client Token.

## Run locally

```bash
chmod +x tool/bootstrap_android.sh
tool/bootstrap_android.sh
flutter pub get
dart run flutter_launcher_icons
flutter analyze --no-fatal-infos
flutter test
flutter run --dart-define=FIREBASE_ENABLED=true --dart-define=FACEBOOK_ENABLED=false
```

Backend checks:

```bash
cd functions
npm ci
npm test
```

`tool/bootstrap_android.sh` generates the Android shell for `com.texiol.crixx`, installs the supplied Firebase Android config, and sets Android 7.0/API 24 as the minimum. Use `FIREBASE_ENABLED=false` for a fully local scoring build.

## Build the APK on GitHub

1. Add the source to a GitHub repository.
2. Create repository Actions secret `GOOGLE_SERVICES_JSON_BASE64` from the complete base64 text of `google-services.json`.
3. Optional: add `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` secrets after configuring the Facebook app and Firebase Facebook provider.
4. Open **Actions → Build CricXii Android APK → Run workflow**.
5. Download `CricXii-Android-APK` from the successful run.

The workflow can build an offline APK without the secret. Secure global Player IDs, Player-ID login/claim, cross-phone friends, and notifications additionally require the included Firebase Functions, Firestore rules, and indexes to be deployed; see [Firebase setup](docs/FIREBASE_SETUP.md).

## Project map

- `lib/domain/` — player, privacy, social, match, and scoring models
- `lib/data/app_store.dart` — account-scoped local state and Firebase synchronization
- `lib/screens/` — auth, profile/settings, player management, social, and match flows
- `functions/` — trusted numeric-ID, password, claim, friend, notification, and deletion services
- `assets/` — original CricXii app icon and avatar pack
- `test/` — scoring, serialization, profile privacy, and ID-format tests
- `docs/` — decisions, architecture, setup, and verification handoff

See [Product plan](docs/PRODUCT_PLAN.md), [Architecture](docs/ARCHITECTURE.md), [Firebase setup](docs/FIREBASE_SETUP.md), and [Verification](docs/VERIFICATION.md).
