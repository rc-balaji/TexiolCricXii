# Team Match hardening — v1.3.0+19

- Team sizes are not capped at eleven.
- Only one selected Joker may appear in both teams, and the engine blocks Joker self-bowling.
- Every enabled extra is checked in the domain engine, not only hidden in UI.
- Per-bowler quota must cover the innings and is checked again before every over.
- Last Player Standing pauses scoring until Continue solo or End innings is chosen.
- Solo mode never swaps the batter for an odd run or completed over.
- Free-hit bowler-credit dismissals are rejected by the engine.
- Host/tracker control uses one device lease and monotonic cloud revisions.
- Completed result navigation never forces network access. Cloud retry is explicit and available later from History.
- Team participant Watch reads one canonical shared document while open.
- Firestore queries remain participant-scoped even though exact pre-create transaction reads are relaxed for authenticated sessions.
