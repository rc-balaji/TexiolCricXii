# Team Match flow hardening — v1.4.0+20

- Setup shows only explicitly selected current players during team assignment.
- Joker is opt-in and remains the only player allowed in both teams.
- Every match-start path resolves and stores the first batting team before scoring begins.
- Timed toss calls are accepted only while the animation runs and the random result is revealed only after completion.
- A missed call never exposes the hidden result and always offers deterministic recovery paths.
- Opening-bowler quota and Joker self-bowling checks apply to toss, manual, skipped and previous-winner starts.
- Linked rematches retain immutable series identity and monotonic series match numbering.
- Match, day and series awards are derived from completed Team Match delivery points.
- Singles and Team career ledgers remain separate; All is a display-time aggregate only.
- Cloud sync remains optional at result exit and retryable from result/history.
