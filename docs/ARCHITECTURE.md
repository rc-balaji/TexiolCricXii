# CricXii v1.3.0 architecture

## Identity

Firebase Anonymous Authentication remains an invisible transport/session layer. The CricXii account is selected by the custom email/password account record and bound to a numeric Player ID through `sessions/{firebaseUid}`.

## Canonical match ownership

`matches/{matchId}` is now the canonical shared record for the **entire** Singles lifecycle.

- `creatorPlayerId` is the host/controller.
- `participantIds` defines who may read/watch the match.
- `status` can be draft/drawing/live/completed.
- `matchJson` contains the complete serialized match state, including draw/order, bowling plan, score events, audit trail and point rules.
- Only the host can mutate/delete the canonical record.
- Every participant can read it from their own CricXii session.

The private `accountStates/{playerId}` document remains a device/account recovery cache; it is not the source of truth for another player's match access.

`teamMatches/{matchId}` is the equivalent canonical Team Match record. It stores both teams, rules, Joker identity, toss, innings, individual bowling limits, score events, audit state and controller lease. Team Match JSON is excluded from `accountStates`, preventing stale private snapshots from resurrecting an older innings.

## Cross-device behavior

- Host creates a match -> canonical shared match is queued immediately.
- Participant starts/resumes app -> participant-ID query discovers applicable active/completed matches.
- Participant opens Watch -> a listener watches only that match document while the screen is open.
- Host scores/reorders/replaces bowler -> the serialized latest-state sync queue pushes the newest snapshot in sequence.
- Host completes -> participant Watch changes to Final and career history can rebuild from the same record.
- Host cancels -> shared record is deleted; participants remove the ghost active card on listener/refresh.

## Career stats

Career Singles stats are rebuilt only from completed matches in which the active Player ID participated. Match creator identity does not affect career credit.

Team career stats are rebuilt separately. A Joker's two team appearances are combined for personal runs/points, but the Joker receives no win because they represented both sides.

## Spark-read discipline

The Home screen does not keep a permanent live query open. App foreground/manual refresh discovers matches. Realtime listening is limited to the one match a participant is actively watching.
