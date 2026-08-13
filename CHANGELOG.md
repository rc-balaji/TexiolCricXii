# CricXii v1.1.1+17

- Fixed shared-active-match unit test isolation by lazily initializing SharedPreferences.
- Centralized active-match visibility policy: every participant can see draft/drawing/live matches; completed matches are history only.
- Kept match control host-only and requires the host to remain a participant.
- Added Flutter test binding initialization for the shared active-match integration tests.
- No scoring, account, history, PDF, friend, or Firestore schema behavior changed.

# CricXii changelog

## 1.1.0+16 — Shared Active Match Watch

- Shared `matches/{matchId}` now exists from match creation through drawing, live scoring and completion, not only after completion.
- Every registered participant can discover an unfinished match on app startup/foreground refresh and open a read-only **Watch** screen.
- Participant Watch uses a single-document Firestore snapshot listener only while the screen is open, showing Playing Now, current bowler, live ranking, remaining order and recent balls.
- Host ownership is enforced in three layers: Home routing, every AppStore match mutation, and Firestore rules.
- Non-host participants cannot score, undo, reorder, add players, replace bowlers, reset the draw or cancel the match.
- Host cancellations use a persisted pending-delete queue so participant devices do not keep ghost Resume/Watch cards after temporary network failures.
- Home refreshes shared matches when the app returns to the foreground and also exposes pull-to-refresh / Refresh Matches.
- Rapid local commits now use an serialized latest-state cloud-sync queue, preventing older score snapshots from racing newer snapshots.
- Shared match writes are fingerprinted so unchanged historical matches are not rewritten on every ball.
- Match creation/start/live-player-add/final completion can wait for the serialized cloud sync, improving cross-device visibility at important lifecycle boundaries.
- Existing Build 15 active and completed creator-owned matches migrate with the same Match IDs.
- Added shared-active-match tests for participant visibility, host ownership and live-score serialization.

## 1.0.2+15 — Shared Participant History

- Fixed the creator-only history bug: completed Singles matches now have a canonical shared Firestore record under `matches/{matchId}`.
- Every registered participant loads completed matches by their numeric Player ID, regardless of who created the match.
- Career Runs, Points, Wickets, Catches, Matches and Wins are rebuilt from the active player's completed participant history on sign-in/startup.
- Added one-time migration for Build 14-and-older creator-side completed matches; existing Match IDs are reused so migration does not duplicate games.
- Added Profile → Singles career stats Sync button for manual history/stat refresh when another device has just completed a match.
- Shared match records are creator-write / participant-read in Firestore rules.
- Reopening a previously completed match removes its stale shared completed copy until it is completed again.
- Reset Local Cricket Cache now preserves completed shared match history.
- Added shared-history tests proving a player receives career credit for matches created by another player.

## 1.0.1+14 — Singles Match V1

- Promoted the app to the first `1.0.0` Singles release.
- Added over-based match setup with half-over convention (`1.5 = 9 legal balls`).
- Kept both Ball Tracker and Direct Runs modes.
- Added randomized phone-pass order plus shuffled face-down secret cards.
- Added optional balanced random bowling-plan generation after batting order confirmation.
- Added full-over / final-partial-over bowling blocks and fairness constraints.
- Added mid-over bowler replacement/injury handling without rewriting past deliveries.
- Added live-match controls to add a player and reorder only uncompleted future players.
- Added local Live Match ranking / current batter / next order / recent balls screen.
- Rebalanced default scoring to wicket 5, catch 2, direct run-out 3, assisted run-out 1, stumping 2.
- Added reusable saved point presets and default-preset selection.
- Added match/event/audit timestamps and dynamic daypart match names.
- Added rank-order rematch action after completion.
- Added date-wise overall performance view and multi-page performance PDF.
- Upgraded match scorecard to one-page CricXii-branded output using the real app logo.
- Added bowling planner tests and updated scoring tests for balanced defaults.
- Explicitly deferred remote live-share link, web viewer, comments and Ask-to-Join.

## 0.3.1+12

- Analyzer fixes for the profile/PDF build.

## 0.3.1+11

- Friend-request profile state and profile navigation improvements.
- One-page scorecard redesign.

## 0.3.0+10

- Fresh Start analyzer fixes.

## 0.3.0+9 — Fresh Start account architecture

- Anonymous Firebase session foundation with custom CricXii account layer.
- Google/Facebook/claim flow removed.
- Simplified player/social collections and notification lifecycle.

## 1.0.1+14
- Rebuilt the Performance header and metrics as a responsive full-width layout.
- Added Daily PDF Report Builder with section checkboxes, per-match selection, in-app content preview, share, and download.
- Daily PDF can include overview/day-only points, Top 3, overall ranking, player performance, match-wise winners, and full ranking tables per selected match.
- Added Bowled Bonus scoring: default wicket 5 + bowled bonus 2; configurable and saved in point presets.
- Added Resume and Cancel/Clear controls for unfinished matches on Home.
