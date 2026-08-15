# CricXii v1.6.2 verification

## v1.6.2 avatar privacy checks

- `Player.toPublicJson()` never exposes `avatarUrl`, `privateAvatars`, or `avatarImageSourceHash`.
- Shared Singles/Team participant snapshots publish `avatarUrl: null`; other devices refresh the public player record for the rendered thumbnail.
- A saved custom URL generates a compact rendered avatar before profile save completes; failure produces a visible validation error instead of silently creating an owner-only photo.
- Saved custom avatars show a thumbnail, name, explicit selected state and delete control.
- Mobile avatars and all PDF exporters prefer the rendered thumbnail and retain preset fallbacks for legacy/offline data.


## v1.6 scorecard regression checks

- Team result screen and Team PDF show the same batter order, dismissal text, R/B/4s/6s/SR, Extras, Total, Yet to Bat and bowling figures.
- Bowling table columns are O/M/R/W/NB/WD/ECO and bowlers are shown in first-appearance order.
- Fall of Wickets records dismissed player, cumulative score and legal-ball over position.
- Partnerships split when the batting pair changes or a wicket falls and include each batter contribution.
- Captain, wicketkeeper and Joker markers remain visible in Team scorecard labels.
- Singles result screen shows scorecard first and official ranking separately; Direct Runs displays `-` for ball-derived fields.
- Singles PDF contains a scorecard section/page and a separate ranking page.
- Today Performance full-match preview/PDF uses full scorecards plus rankings for Singles and Team selections.
- Large teams and repeat Super Overs paginate without wrapping a complete innings inside one unsplittable PDF column.

## v1.5 focused regression checks

- Team wicket creates a blocking next-batter choice and prevents another delivery until resolved.
- The chosen batter survives undo/rebuild through `nextBatterByWicketSequence`.
- Team live automatic prompts use one priority path and modal guards to prevent duplicate next-bowler / next-batter / Last Player Standing prompts.
- A tied main match enters `tieBreak`; Super Over innings use one over and a two-wicket cap.
- A tied Super Over returns to `tieBreak` and Super Over 2, 3, etc. can be appended.
- Repeated innings keep dismissal counts and not-out bonuses correct when Team career stats are applied or reverted.
- Today Performance filters strictly by `completedAt`, includes completed Singles + Team Matches, and excludes unfinished/missing-completion records.
- Report Builder defaults to all completed matches and permits All / Singles / Team filtering, individual selection, Select shown / Clear shown, and section selection.
- Export requires at least one selected match and one selected section; title/filename switch between Singles, Team and Overall automatically.
- Team/daily scorecards use adaptive multi-page layouts for repeated Super Overs and large rosters.

## Commands for a Flutter-enabled workstation / CI

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The repository package itself does not vendor a Flutter/Dart SDK. If verification is performed in an environment without those executables, run the repository/static checks below and let GitHub Actions or a Flutter workstation execute the analyzer/test commands above before release publication.

## Repository/static checks

```bash
git diff --check
grep -Rni "nextBatterIndex\|matchIds:" lib test || true
grep -Rni "TeamMatchStatus.tieBreak" lib test
grep -Rni "startSuperOver\|selectNextBatter" lib test
```

---

## Historical v1.4 verification

Required scenarios:

1. Player 2 creates a 4-player match. Player 1 signs in on another device and sees the match as **Watch**, not Resume.
2. Player 1 cannot score, undo, cancel, change batting order, add a player, replace the bowler or reset the draw.
3. Player 2 can still resume/control after leaving and reopening the app.
4. While Player 1 Watch is open, Player 2 score updates appear through the shared match listener.
5. If Player 2 cancels, Player 1 Watch becomes unavailable and the active card disappears after refresh.
6. When the match completes, all registered participants receive the same match in applicable History and their own career totals rebuild from completed shared records.
7. Adding a new registered player during a live match updates `participantIds`; that player's account can discover/watch after refresh.
8. Existing Build 15 active/completed creator-side matches keep the same Match IDs when migrated.
9. Rapid host scoring does not allow an older queued snapshot to overwrite a newer score snapshot.
10. Completed-history PDFs and Today Performance continue to use completed match records only.

## Team Match scenarios

1. Create teams larger than eleven and confirm setup has no hard cap.
2. Create 3 vs 3 with one shared Joker; confirm the Joker appears in both orders and cannot be selected to bowl while batting.
3. Toggle every extra independently and confirm disabled types never appear and are rejected by the engine.
4. Configure uneven bowling limits such as 3/3/2/2 overs; exhausted bowlers must be disabled for the next over.
5. Dismiss all but one batter. Choose Continue solo, score an odd run and complete an over; the same batter must remain striker.
6. Complete both innings and verify target/result, Team career stats and Team PDF batting/bowling tables.
7. On the result page, leave while sync is pending. Home/Profile History must retain the match with a pending cloud icon.
8. Reopen the result from History, press Sync now, and verify the icon changes to cloud-done after rules/indexes are deployed.
9. Sign in as a participant on another phone and confirm Team Match Watch updates without scoring controls.
10. Send and accept a Friend Request to confirm pre-create exact-document reads no longer return permission-denied.
11. With a large friend list, search/select only the current players and confirm only that roster reaches team assignment.
12. Confirm Joker is absent until enabled, then select exactly one shared Joker.
13. Run an in-app toss: choose the flipping team, start the timer, tap the caller's Heads/Tails choice during the three-second spin and confirm no result is revealed early.
14. Let the toss timer expire without a call and verify Restart toss, Start over and Skip toss paths.
15. Verify physical toss and no-toss modes require an explicit winning/first-batting team before opening-bowler selection.
16. Complete a match, create the next match with the same teams, and verify the previous winner can choose Bat/Bowl without a toss.
17. Create another linked match with changed players/teams and confirm Series match number and Series award continue.
18. Confirm Player of Match, Today and Series points agree with the recorded delivery points.
19. On own and public profiles, switch All/Singles/Team Match and confirm filtered totals; on own profile confirm histories remain in separate sections.
