# CricXii v1.1.0 verification

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
