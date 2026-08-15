# CricXii v1.5.0+22 migration

This build is designed to load existing v1.4 Team Match JSON without a destructive migration.

## Team Match schema additions

`TeamMatchStatus` adds `tieBreak`. `TeamInnings` adds optional Super Over limits/metadata and persisted live next-batter state:

- `ballLimitOverride`
- `wicketLimitOverride`
- `isSuperOver`
- `superOverNumber`
- `nextBatterByWicketSequence`
- `pendingNextBatterEnd`
- `pendingNextBatterWicketSequence`
- `swapAfterNextBatter`

All new JSON fields have safe defaults when absent. Existing v1.4 innings therefore continue to deserialize.

## Batting order behavior

`TeamSide.battingOrder` remains in storage for backward compatibility and deterministic default openers, but v1.5 setup no longer asks the host to arrange a full batting order. New Team Matches initialize that list from the selected roster. Every new wicket that creates a vacant crease end pauses scoring and asks the scorer to choose the incoming batter.

The selected batter is saved against the wicket delivery sequence. Undo/rebuild can therefore restore the same choice. If an older active innings has a blank batting end but no persisted v1.5 choice, the engine uses roster order only as a legacy fallback so the match remains playable.

## Super Overs

A completed two-innings round with equal totals now enters `tieBreak` instead of immediately completing. Starting a Super Over appends another two-innings pair. Each Super Over innings uses one configured over (`ballsPerOver` legal balls) and a two-wicket cap. A repeated tie returns to `tieBreak`, allowing another Super Over. Choosing **Finish match as tie** marks the match completed without a winner.

No existing completed v1.4 Team Match is automatically reopened or converted into a Super Over.

## Daily Performance

Today Performance now includes only matches whose `completedAt` falls on the selected local day. Completed records with a missing `completedAt` are not assigned by `createdAt` or `startedAt`. This keeps reporting aligned with the actual completion/session day and avoids moving unfinished or malformed records into a report.

Singles and Team career storage remain separate. The mixed daily report only aggregates the selected completed matches for report/display purposes.
