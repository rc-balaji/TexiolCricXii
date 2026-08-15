# Firebase setup — CricXii v1.3.0

## Authentication

Enable **Anonymous** only for the requested test architecture. Google/Facebook provider packages and flows are removed from the app.

## Android config

Download your project's Android `google-services.json`, Base64 encode it, and store the encoded text in the GitHub repository secret:

`GOOGLE_SERVICES_JSON_BASE64`

The GitHub workflow decodes it only during the build and copies it into the generated Android project. Do not commit `google-services.json` to the source repository.

## Firestore

Deploy the included rules and indexes from the project root before testing Friend Requests or Team Match cloud sync:

```bash
npx --yes firebase-tools@latest deploy --project crixx-59eca --only "firestore:rules,firestore:indexes"
```

The included indexes cover recent-first `matches` and `teamMatches` participant history (`participantIds` array membership plus descending `activityAt`).

The v1.3 rules intentionally allow an authenticated CricXii session to perform an exact `get` for a random Match ID or deterministic Friend Request pair ID. This is needed because Firestore transactions read a document before deciding whether to create it. Collection queries remain participant-scoped; the rules are not globally open.


## Shared-history migration test

- Keep the original creator account/device data from Build 14 or older.
- Deploy the new Firestore rules first.
- Open v1.3.0 as the creator and press Profile → Singles career stats → Sync if needed.
- Confirm `matches/{matchId}` documents are created once with `creatorPlayerId` and all `participantIds`.
- Sign in as a registered participant on another device/account.
- Confirm their own Profile shows the applicable completed matches and rebuilt Runs/Points/Wickets/Catches/Matches/Wins even though they did not create those matches.

## Required tests

- New main account register -> direct Home.
- Sign out -> direct Login without pressing Back.
- Same email/password -> same Player ID login.
- Add another player -> creates separate account immediately.
- Exact Player ID search -> player result -> Send Request -> Request Sent.
- Receiver app login/start -> initial notification sync.
- Receiver already open -> Notifications Refresh -> request appears.
- Accept -> receiver request notification becomes Accepted + read.
- Sender Refresh -> new unread Accepted notification appears.
- Mark read, Mark unread, Delete notification and Delete All notifications.
- Remove friend and verify both sides after refresh.
- Existing Singles scoring and PDF export still work.

## Active participant Watch test

- Creator starts a match with another registered Player ID.
- On the participant account/device, reopen the app or use Home -> Refresh matches.
- The match must appear as **Watch / Read only**.
- Keep Watch open and score on the creator device; the participant view should update from the one canonical match document.
- Participant-side mutation attempts are blocked by both AppStore host checks and Firestore rules.
