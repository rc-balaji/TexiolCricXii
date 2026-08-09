# Changelog

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
