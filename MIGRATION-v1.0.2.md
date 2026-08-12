# CricXii v1.0.2 shared-history migration

This build fixes the legacy creator-only match-history architecture.

## Before testing

1. Deploy the included `firestore.rules` and `firestore.indexes.json`.
2. Install/open this build on the account/device that created the old completed matches.
3. Keep internet connected and open **Profile** once. The startup sync runs automatically; the Sync icon beside **Singles career stats** can be pressed to retry immediately.
4. Sign in to each registered participant account on its own device/account. Their completed participant history is fetched from the shared `matches` collection and their own career stats are rebuilt.

## What is migrated

- Only completed Singles matches are migrated to the canonical shared `matches/{matchId}` record.
- The original Match ID is reused, so repeating migration does not duplicate a match.
- The shared document records the creator and every participant Player ID plus the complete match JSON/event history.
- Draft/live matches stay in the creator's private/local state until completion.

## Important

Do not delete the old creator account state before opening/syncing this build if you want to preserve matches that only exist in the Build 14-and-older creator state.
