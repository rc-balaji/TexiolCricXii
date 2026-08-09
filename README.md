# CricXii

CricXii is Texiol's Android-first scorer for real local Singles cricket. It supports Android 7.0 or newer, an optional ball tracker, direct-total scoring when nobody can track every ball, a private batting-order draw, player/gang profiles, configurable points, rankings, and shareable PDF scorecards.

## What works in this source build

- Local profiles with persistent one-tap profile switching
- One home gang per player with Leader, Co-leader, and Member roles
- Friends and locally created unclaimed players with generated Player IDs
- Singles match creation with 6, 9, 12, 18, and 36-ball presets or a custom limit
- `1.5 overs = 9 balls` as a deliberate CricXii product rule
- Secret face-down draw; the final player receives the remaining card automatically
- Optional post-draw order adjustment and live "send next player first" recovery
- Ball-by-ball scoring, wides/no-balls, wickets, undo, and current-turn reset
- Direct runs + Out/Not Out scoring without storing individual deliveries
- Bowler, catcher, direct/assisted run-out, and stumping attribution
- Configurable point rules and Runs-only or Overall-points official rankings
- Permanent local match history, career stats, and generated PDF scorecards
- Optional Firebase email/password sign-in with private cloud recovery
- GitHub Actions analysis, tests, and release APK artifact

Team matches, cross-phone live match joining, Google account linking, and secure Player-ID claiming are intentionally planned after the Singles foundation.

## Run locally

Install the stable Flutter SDK and Android tooling, then run:

```bash
chmod +x tool/bootstrap_android.sh
tool/bootstrap_android.sh
flutter pub get
flutter test
flutter run --dart-define=FIREBASE_ENABLED=true
```

The bootstrap command generates the standard Android platform shell with application ID `com.texiol.crixx`, copies `firebase/google-services.json` into the Android module, and adds the Google Services Gradle plugin. To run without Firebase, temporarily move that JSON out of `firebase/` and use `--dart-define=FIREBASE_ENABLED=false`.

## Build the APK on GitHub

1. Create a GitHub repository and add this source.
2. In repository **Settings → Secrets and variables → Actions**, create `GOOGLE_SERVICES_JSON_BASE64` containing the base64-encoded contents of `google-services.json`.
3. Open **Actions → Build CricXii Android APK → Run workflow**.
4. Download the `CricXii-Android-APK` artifact from the completed run.

If the secret is absent, the workflow still builds a fully usable offline APK. The Firebase JSON is excluded from normal Git commits even though Firebase classifies Android configuration identifiers as non-secret.

## Project map

- `lib/domain/` — serializable match model and deterministic event-based scoring engine
- `lib/data/` — persistent local store, Firebase authentication, and private cloud recovery
- `lib/screens/` — mobile flows from onboarding through final scorecard
- `lib/export/` — PDF scorecard generation and sharing
- `test/` — scoring, dismissal-points, 9-ball, undo, and serialization tests
- `docs/` — product decisions, architecture, and Firebase rollout
- `.github/workflows/android.yml` — reproducible Android release build

See [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md), and [docs/VERIFICATION.md](docs/VERIFICATION.md).
