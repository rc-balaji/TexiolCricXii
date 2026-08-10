# CricXii v0.3.0+9 verification

Static package verification performed before ZIP creation:

- No Google sign-in package/import/flow.
- No Facebook sign-in package/import/flow.
- No Cloud Functions package/folder/runtime dependency.
- No Firebase App Check dependency in this prototype build.
- Anonymous Firebase session is the only Firebase Auth flow in source.
- No temporary-player or claim flow references in `lib/`.
- Login email is not stored inside the `Player` profile model.
- Password plaintext is never written by AppStore; credential docs use salt + verifier.
- Friend requests/notifications are keyed by Player IDs.
- Social refresh uses single-field Firestore queries; custom composite indexes are empty.
- Local account state keys bumped to v4 for the fresh reset.
- GitHub release build command uses a YAML multiline shell block.
- Source ZIP excludes `google-services.json`, service-account JSON and private-key files.

The container used to prepare this package does not include the Flutter SDK, so final Flutter type analysis, unit tests and Android compilation run in the supplied GitHub Actions workflow.
