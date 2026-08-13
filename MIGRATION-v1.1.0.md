# CricXii v1.1.0 shared active-match migration

This build extends the canonical `matches/{matchId}` record from completed history to the full match lifecycle: drawing, live and completed.

## Required Firebase step

Deploy the included rules before testing participant Watch mode:

```bash
npx --yes firebase-tools@latest deploy --project crixx-59eca --only "firestore:rules"
```

No new composite index is required for shared active-match lookup. The app queries `matches` by `participantIds arrayContains <activePlayerId>`.

## Existing Build 15 data

1. Do not delete the creator account state or local app data before migration.
2. Install/open v1.1.0 on the match creator account/device at least once.
3. Startup/Refresh uploads existing creator-owned drawing/live/completed matches using their existing Match IDs.
4. On another registered participant account, reopen the app or Home -> Refresh matches.
5. Foreign unfinished matches appear as **Watch** and are read-only. Completed matches remain in History and career stats.

## Ownership rule

- Creator/host: create, draw, start, score, undo, reorder, add player, replace bowler, cancel.
- Participant: read/watch the shared match and open player profiles/history; no score/setup mutation.
- Completed match: all participants keep the same canonical match in their applicable history.

## Cancellation

A host cancellation queues a shared-document delete. Participant devices remove the foreign unfinished match after refresh or immediately if its Watch screen is open.
