# CricXii

CricXii is Texiol's Android-first scorer for real local cricket. Version `0.2.2+6` keeps the Singles scoring engine and adds a Spark-first social flow, full temporary-player registration, manual notification sync, exact Player ID search, and a more polished PDF scorecard.

## Included in v0.2.2

- One Firebase account owns one independent numeric Player ID. Normal account Player IDs can now be reserved directly with secured Firestore transactions on Spark.
- Exact numeric Player ID search, request sending, outgoing Pending state, incoming notification, accept/reject, accepted friend list, and remove-friend flow.
- Social sync is intentionally conservative: one refresh on fresh sign-in/app launch, then manual Refresh from Notifications while the app remains open. No continuous listener or polling is required.
- Temporary players now use a full registration page with name, claim email, Instagram, batting style, and avatar instead of a small dialog. When Firebase is connected, the numeric ID is reserved in Firestore immediately and becomes searchable.
- Spark claim flow: the player signs in/registers on their own phone with the same email and claims the already-registered numeric Player ID. Firebase Auth owns the password; no password is stored in Firestore.
- Legacy Player-ID/password backend Functions remain in the source only as optional compatibility for a future backend mode.
- Editable profile with batting/bowling styles, DOB-derived age, bio, social links, five original avatars, provider photos, private HTTPS avatars, and privacy controls.
- Existing Singles scoring: 6/9/12/18/36/custom balls, secret draw, optional tracker, direct totals, dismissals, undo/reset, points/runs rankings, history, and sharing.
- Advanced PDF scorecard with winner hero, player avatar/photo fallback, top-three podium, richer final ranking, match metrics, and official match details.
- GitHub Actions analyzes/tests Flutter and builds the Android release APK.

Team-match scoring and multi-phone live match scoring remain future phases.

## Spark-first Firebase setup

For current testing, deploy only Firestore rules and indexes:

```bash
npx --yes firebase-tools@latest login
npx --yes firebase-tools@latest deploy --project YOUR_PROJECT_ID --only "firestore:rules,firestore:indexes"
```

Then build with Firebase enabled. Email/password, Google/Facebook authentication, normal Player ID creation, exact Player ID search, friend requests, notifications, and accepted-friend synchronization use Firebase Authentication + Firestore.

The `functions/` folder is retained only for optional legacy Player-ID/password login, server-side allocator compatibility, and administrative cleanup. The v0.2.2 temporary-player claim path works directly on Spark using Firebase Auth email identity + Firestore rules. Deploying Functions requires the Firebase project configuration appropriate for Cloud Functions.

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

## Build the APK on GitHub

1. Add the source to a GitHub repository.
2. Create repository Actions secret `GOOGLE_SERVICES_JSON_BASE64` from the complete base64 text of `google-services.json`.
3. Optional: add `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` after configuring Facebook.
4. Open **Actions → Build CricXii Android APK → Run workflow**.
5. Download `CricXii-Android-APK` from the successful run.

## Project map

- `lib/domain/` — player, privacy, social, match, and scoring models
- `lib/data/app_store.dart` — account-scoped local state and Firebase synchronization
- `lib/screens/` — auth, registration, profile/settings, social, and match flows
- `lib/export/scorecard_export.dart` — PDF scorecard generation and sharing
- `functions/` — optional trusted Player-ID, password, claim, and cleanup services
- `assets/` — CricXii app icon and avatar pack
- `test/` — scoring, serialization, profile privacy, and ID-format tests
- `docs/` — architecture, setup, and verification handoff


## Spark build mode

The default GitHub Android workflow builds with `FUNCTIONS_ENABLED=false`. Friend search, friend requests, notifications refresh, account Player-ID reservation and scoring use Firebase Authentication + Firestore directly. The `functions/` folder is retained for an optional future backend upgrade.
