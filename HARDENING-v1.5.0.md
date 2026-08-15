# CricXii v1.5.0+21 hardening

## Duplicate live prompt race

The Team live screen previously had independent rebuild/post-frame paths that could observe the same unresolved state while a modal action was closing or its store commit was still in flight. That could schedule the same automatic prompt twice, most visibly **Choose next bowler**.

v1.5 treats automatic prompts as a single priority queue:

1. Choose next batter
2. Last Player Standing decision
3. Choose next bowler

Dedicated `_nextBatterSheetOpen`, `_soloDialogOpen`, `_bowlerSheetOpen` and `_working` guards remain active through the modal result, AppStore mutation and follow-up state evaluation. A rebuild schedules at most one prompt from the priority chain.

## Live batting invariant

After a wicket creates a vacant batting end and eligible batters remain, `TeamInnings.awaitingNextBatter` becomes true. `recordDelivery` rejects another delivery until `selectNextBatter` resolves that state. The selected player is persisted by wicket sequence and restored during undo/rebuild.

## Super Over invariant

Every round is stored as an innings pair: main match `0/1`, Super Over 1 `2/3`, Super Over 2 `4/5`, and so on. Odd-index completion compares only against the immediately preceding even innings. Equal totals return to `tieBreak`; unequal totals complete the match.

Each Super Over innings carries its own ball and wicket overrides, so normal-match limits remain unchanged. Team appearance stats are calculated per innings and merged afterward, preserving repeated dismissals and per-innings not-out bonuses across any number of Super Overs.

## Reporting invariant

Daily reports are generated from explicit selected match keys (`singles:<id>` / `team:<id>`). Export is blocked if no match or no report section is selected. Report type and filename are derived from the selected formats, not from all matches present that day.
