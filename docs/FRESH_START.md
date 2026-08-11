# v1.0.0 Fresh Start checklist

This version intentionally starts a new account schema. Local SharedPreferences keys are bumped to `v4`, so old v0.2.x CricXii account state is not automatically treated as a valid v1.0 login.

## Firebase Console reset

1. Authentication -> Sign-in method: keep **Anonymous** enabled. Disable Email/Password, Google and Facebook if you want the requested Anonymous-only setup.
2. You may delete the old Authentication users. On the next launch CricXii silently creates/refreshes an anonymous Firebase transport user.
3. Delete old Firestore data before first v1.0 test if you want a completely clean database.
4. Deploy this ZIP's `firestore.rules` and `firestore.indexes.json`.
5. Build/install v1.0.0 and register the first CricXii account from the app.

## New collections created by the app

- `loginCredentials`
- `players`
- `sessions`
- `accountStates`
- `friendRequests`
- `notifications`

Subcollections:

- `players/{playerId}/friends`
- `players/{playerId}/contactFields`

Existing cricket feature collections `gangs` and `matches` remain allowed by the rules for compatibility with the current scorer architecture.

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
