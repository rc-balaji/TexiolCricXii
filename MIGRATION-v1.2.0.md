# CricXii v1.2.0+18 migration / hardening notes

This release keeps the existing player IDs, accounts, friends, matches, score events and history. Do **not** delete Firestore data before upgrading.

## Firebase deploy

Deploy both the new security rules and the new match-history index:

```bash
npx --yes firebase-tools@latest deploy --project crixx-59eca --only "firestore:rules,firestore:indexes"
```

The new `matches` composite index is used for recent-first participant history pagination (`participantIds` + `activityAt`). The app contains a temporary no-index fallback, but full Load Older behavior should use the deployed index.

If Firebase asks whether to delete older indexes that are still present in the project but absent from this repository, answer **N** unless you intentionally want to remove them.

## Upgrade order

1. Upgrade a creator/host device first and open/refresh CricXii while online.
2. Existing creator-owned shared matches are retained under the same Match IDs. Old matches receive best-effort tie-break metadata when a previous completed match is available.
3. Upgrade participant devices and use Home/Profile refresh to pull the latest shared state.
4. No account reset, collection reset or match-history deletion is required.

## New controller behavior

- A live match has one scoring-controller device lease at a time.
- Another phone signed into the same host/tracker account becomes watch-only while that lease is active.
- `Take control on this device` explicitly hands control to the current phone. Only do this after the other scoring phone has stopped; unsynced offline edits on two phones cannot be automatically merged.
- Host controls match setup. A selected tracker may enter/undo/reset score but cannot edit participants/order/setup.
- The cloud icon on live scoring screens shows synced, waiting, or retry state.

## Tie rule

For equal primary scores, CricXii uses the most recent applicable previous completed match ranking/order as the tie-break. Example: previous rank `P1, P2, P3, P4`; current points `P1=10, P2=20, P3=10, P4=15` produces `P2, P4, P1, P3`. A player absent from the previous match falls back to the current batting order, then stable participant order.

## Date / history behavior

Daily performance belongs to the match completion date (`completedAt`, then started/created fallback). Automatic `Morning/Afternoon/Evening/Night Match N` numbering counts only matches created by the current host that day. Shared history loads recent matches first and exposes Load Older pagination.
