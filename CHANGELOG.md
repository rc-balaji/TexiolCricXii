# Changelog

## 0.2.2+6 — Analyzer fixes

- Fixed ternary/null-coalescing precedence in Spark player claim transaction.
- Fixed nullable FriendRequest field access by promoting a local request variable.
- Removed unnecessary dart:typed_data import from PDF export.
- No functional flow changes from 0.2.2+5.

## 0.2.2+5 — Spark social + registration + scorecard polish

- Added Spark-first numeric Player ID reservation for normal Firebase accounts, without requiring Cloud Functions for first profile creation.
- Moved friend request send/accept/remove and notification read flows to secured Firestore client transactions so social testing works on Spark.
- Added exact Player ID search with visible Request sent / Request received / Friends states and a cached outgoing-pending list.
- Changed social refresh to one sync on fresh sign-in/app launch plus explicit manual refresh while the app stays open; removed automatic Friends-tab refreshes.
- Rebuilt temporary-player creation as a full registration screen with name, claim email, Instagram, batting style and avatar. Connected temp IDs are reserved in Firestore immediately and are globally searchable.
- Added a Spark-native email-identity claim flow so the registered player can sign in on their own phone and claim the same Player ID without storing passwords in Firestore.
- Upgraded PDF scorecards with winner hero, player avatars/photos, podium cards, richer ranking rows and match-detail cards.
- Added the outgoing friend-request composite index and updated Firestore rules for Spark account mapping and social transactions.
- Kept the existing Functions backend as optional legacy compatibility; the default GitHub APK build disables Functions.

## 0.2.1+4 — GitHub analysis hotfix

- Fixed the onboarding async-context analyzer warning by retaining the app store before awaiting.
- Removed the unused public-profile import so GitHub Actions analysis completes cleanly.

## 0.2.0+3 — Player & Social foundation

- Replaced prefixed player IDs with high-scale numeric server allocation starting at six digits.
- Added lossless local migration for v0.1 player references and match history.
- Enforced one independent player per Firebase account; removed profile-switch UI.
- Added separate provisional-player registration, temporary initial password, secure claim, and pending-notification routing.
- Added searchable fixed-height player/friend lists, edit/remove/archive controls, requests, notifications, and public friend profiles.
- Added full profile editing, batting/bowling styles, DOB age, bio, social links, five avatars, provider photos, and private avatar URLs.
- Added generated IDs/names for private custom avatars and lossless migration from URL-only avatar records.
- Added per-contact privacy rules and normalized Firestore contact documents.
- Added email, Player-ID, Google, and credential-gated Facebook login/link settings plus reset, provider replacement/disconnect, and account deletion.
- Added secure provisional-profile editing/claim transfer, cloud-backed full reset, social refresh/reconciliation, and orphan cleanup on provisional deletion.
- Added trusted TypeScript Functions, Firestore indexes/rules, allocator tests, and Functions CI.
- Added an original CricXii app icon/avatar pack and launcher-icon generation.

## 0.1.1+2 — GitHub build hotfix

- Removed Flutter's generated counter-demo widget test before analysis.
- Resolved the 11 findings reported by the first GitHub Actions run.

## 0.1.0+1 — Singles foundation

- Added local player/gang profiles, Singles match setup, secret draw, both scoring modes, dismissals, undo/reset, rankings, history, PDF scorecards, optional Firebase recovery, tests, and APK CI.
