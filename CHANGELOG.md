# Changelog

## 0.3.0+9 — Fresh Start account architecture

- Replaced the v0.2.x provider/claim account architecture with a fresh Anonymous-only Firebase transport session plus a simple CricXii email/password account layer.
- Removed Google sign-in, Facebook sign-in, Firebase App Check and Cloud Functions dependencies from the app/build.
- Removed temporary Player IDs, claim flow, provider avatar identity and legacy account UID state from the Player model.
- Main registration now asks for name, login email, password, batting style and avatar once and opens Home directly.
- Player Management/Match/Gang add-player flow now creates a separate full account immediately.
- Login email is no longer a Player profile field and is not requested again in Profile Edit.
- Added random eight-digit numeric Player IDs with Firestore transaction collision checks.
- Reworked friends around exact Player ID search and Player-ID based request documents.
- Reworked notification refresh for initial sync plus explicit manual Refresh instead of continuous polling.
- Accepting a friend request marks the receiver request notification accepted/read and creates a new unread accepted notification for the sender.
- Added notification Mark read, Mark unread, Delete and Delete All. Pending request deletion rejects the request first.
- Removed social refresh composite-index dependency by querying one Player-ID field at a time and filtering status in Dart.
- Sign out/delete now pop directly to the root Login screen.
- Bumped local persistence keys/schema to v4 so the fresh architecture does not silently reuse v0.2.x local account state.
- Retained Singles scoring, gangs, stats, sharing and the advanced avatar/ranking PDF scorecard.

## 0.3.1+11
- Friend request buttons on public profiles now reflect Request sent / Request received / Friends immediately.
- Player identities are tappable from rankings, match winner, friends, sent requests, gangs, player management, notifications, match setup avatars, draw results, and live scoring headers.
- Notifications retain sender Player ID so the sender profile can be opened from activity.
- Scorecard PDF rebuilt as a compact single A4 page, with fixed-height podium cards, one-page match details, ASCII-safe separators, and compact ranking layout for larger matches.
