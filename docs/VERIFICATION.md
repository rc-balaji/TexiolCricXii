# CricXii v1.4.0 verification

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
