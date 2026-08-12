# v1.0.x Fresh Start / migration checklist

This version intentionally starts a new account schema. Local SharedPreferences keys are bumped to `v4`, so old v0.2.x CricXii account state is not automatically treated as a valid v1.0 login.

## Firebase Console reset

1. Authentication -> Sign-in method: keep **Anonymous** enabled. Disable Email/Password, Google and Facebook if you want the requested Anonymous-only setup.
2. You may delete the old Authentication users. On the next launch CricXii silently creates/refreshes an anonymous Firebase transport user.
3. For an already-used Build 14 database, **do not delete creator `accountStates` before v1.0.2 migration** if those documents contain completed matches that have not yet been shared.
4. Deploy this ZIP's `firestore.rules` and `firestore.indexes.json`.
5. Install v1.0.2 on the original match-creator account/device and open Profile/Sync once so legacy completed matches are copied to canonical `matches/{matchId}` records.
6. Then sign in to each participant account and verify their own history/stats.

## New collections created by the app

- `loginCredentials`
- `players`
- `sessions`
- `accountStates`
- `friendRequests`
- `notifications`
- `matches` (canonical completed shared match records)

Subcollections:

- `players/{playerId}/friends`
- `players/{playerId}/contactFields`

The `matches` collection now has a defined role: creator-write, participant-read canonical completed Singles history. `gangs` remains available for the existing local/gang features.

## Old collections that v1.0 no longer uses

If they exist from earlier experiments, they can be removed during the reset:

- `users`
- `playerClaims`
- `playerIds`
- `loginSecrets`
- `loginRateLimits`
- `friendships`
- old function/admin system collections

## First functional test

Register Account A. From Player Management create Account B with B's own email/password. On a second installation/device sign in as B. From A search B's exact numeric Player ID and send a request. On B open Notifications and Refresh, Accept the request, then on A open Notifications and Refresh. A should receive an unread accepted notification and both accounts should show each other under accepted friends.
