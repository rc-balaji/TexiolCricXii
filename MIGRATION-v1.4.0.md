# CricXii v1.4.0+20 migration

1. Replace the prior source with this package and keep `GOOGLE_SERVICES_JSON_BASE64` unchanged.
2. Push `main`; GitHub Actions will install packages, analyze, test and build the release APK.
3. Existing Singles and Team Match data load without reset. Older Team Matches receive their own Match ID as the default Series ID when decoded.
4. New linked rematches store Series metadata inside the existing `teamMatches/{matchId}` JSON, so no new Firestore collection or index is required.
5. Existing v1.3 Firestore rules remain schema-compatible. Deploy the bundled rules if the app reports permission-denied for Friend Requests or cloud sync.
6. Complete one short Team Match and verify result sync, next-match choices, previous-winner start and the All/Singles/Team Match profile filters.

No Firestore deletion, account reset or local-cache reset is required.
