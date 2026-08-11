# Firebase setup — CricXii v1.0.0

## Authentication

Enable **Anonymous** only for the requested test architecture. Google/Facebook provider packages and flows are removed from the app.

## Android config

Download your project's Android `google-services.json`, Base64 encode it, and store the encoded text in the GitHub repository secret:

`GOOGLE_SERVICES_JSON_BASE64`

The GitHub workflow decodes it only during the build and copies it into the generated Android project. Do not commit `google-services.json` to the source repository.

## Firestore

Deploy rules and indexes from the project root using your preferred Firebase CLI setup:

```bash
npx --yes firebase-tools@latest deploy \
  --project YOUR_FIREBASE_PROJECT_ID \
  --only "firestore:rules,firestore:indexes"
```

The app's current social queries use single fields, so no custom composite indexes are required in `firestore.indexes.json`.

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
