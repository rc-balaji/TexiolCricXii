# CricXii v1.2.0+18 hardening matrix

1. **Same account on two phones** — single controller-device lease; second device watch-only; explicit takeover.
2. **Dedicated tracker/scorer** — selected tracker can score/undo/reset live scoring; host-only setup/order/player management remains protected.
3. **Offline scoring** — local score persists immediately, pending/error sync state is visible, retry is supported, and revision checks reject stale overwrite after reconnect.
4. **Equal-score ranking** — previous completed match rank/order resolves ties; deterministic local fallbacks handle new players/first match.
5. **Midnight boundary** — day reports use completion/session date rather than creation date.
6. **Automatic match numbering** — only current host's created matches count toward that day's Match N.
7. **Match-ID collision** — online creation reserves an ID transactionally before canonical shared creation; collision regenerates another ID.
8. **Player added during live match** — participantIds and future order are published canonically so the new participant can discover/watch after refresh.
9. **Lifecycle transitions** — cancel removes shared active state; completion moves participants from active/watch to history; undo returns the canonical match to live; deleting a host account removes host-owned unfinished shared matches before sign-out.
10. **Long history** — participant shared history is recent-first, page-limited and supports Load Older rather than fetching an unbounded archive on every refresh.

Additional privacy hardening: participant-readable shared match payloads do not contain secret-draw card assignments. Match-time public participant snapshots preserve historical rendering even if a live profile later changes or disappears.
