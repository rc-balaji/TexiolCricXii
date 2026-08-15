# CricXii v1.3.0+19 migration

1. Replace the prior source with this package and keep your GitHub Firebase secret unchanged.
2. Deploy both `firestore.rules` and `firestore.indexes.json` before distributing Build 19.
3. Build and sign in once as the existing account. The local state schema upgrades in place and preserves Singles matches, accounts, friends, gangs, presets and history.
4. Use Friends refresh and send one Friend Request to confirm the exact-document transaction rule is deployed.
5. Create a short Team Match, complete it, and verify the result cloud card changes to **Synced with cloud**. Leaving before sync is safe and intentionally allowed.
6. Open Profile → Team History. The cloud icon shows each record's state; opening the result exposes **Sync now / Sync again**.

No Firestore collection deletion or fresh-start reset is required.
