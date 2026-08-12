# CricXii v1.0.2 architecture

## Stable identity layer

Firebase Anonymous Auth remains an invisible Firebase session. CricXii account identity, player profiles, friends and notifications use the Fresh Start data model from v0.3.x. V1 does not reintroduce Google/Facebook login, claim IDs or Cloud Functions.


## Shared completed-match history

`accountStates/{playerId}` remains a private cache/preferences snapshot, but it is no longer the source of truth for completed Singles history. A completed match is canonically stored at `matches/{matchId}` with `creatorPlayerId`, `participantIds`, timestamps and the serialized full match.

- Only the match creator writes/updates the canonical match.
- Every participant can read a completed match that contains their Player ID.
- Sign-in/startup queries shared matches by `participantIds array-contains activePlayerId`.
- The active player career is recalculated from all completed matches in which that Player ID participated.
- Build 14-and-older completed creator-side matches are migrated once using the existing Match ID.
- Draft/live matches stay private/local until completion.

## Match engine

`CricketMatch` stores setup, order, scoring events, point rules, bowling plan, bowler-change audit, created/start/completion timestamps and match audit entries.

- `match_planning.dart`: over conversion and balanced bowling scheduling.
- `scoring_engine.dart`: Ball Tracker and Direct Runs scoring/ranking.
- `live_match_screen.dart`: local live rank, queue and in-progress controls.
- `daily_performance.dart`: date-scoped aggregate performance.
- `scorecard_export.dart`: one-page match PDF.
- `daily_performance_export.dart`: multi-page date performance PDF.

## Bowling plan rules

- Never assign the current batter as bowler.
- Keep each full six-ball over assigned to one bowler.
- Treat a final three-ball half-over as its own block.
- Use the only available bowler when there are only two players.
- Prefer a different bowler for adjacent blocks when alternatives exist.
- Prefer a different bowler across batting-turn boundaries when alternatives exist.
- Balance scheduled legal-ball load across eligible players.
- Mid-over replacement affects future balls only; recorded ScoreEvents preserve the actual bowler.

## Remote live layer

No remote share link, public live viewer, comments or Ask-to-Join exists in v1.0.0. That layer is deferred.
