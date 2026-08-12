# CricXii v1.0.2 verification

Final release verification should run in GitHub Actions:

1. `flutter analyze --no-fatal-infos`
2. `flutter test`
3. `flutter build apk --release ...`

Additional V1 tests cover over conversion and bowling-plan edge cases, including two-player all-overs assignment, no self-bowling, adjacent-over diversity and workload balancing.

Shared-history verification additionally covers:

- A participant receives career credit from a completed match created by another Player ID.
- Unrelated matches are excluded from that player's career totals.
- Legacy creator matches are uploaded with the original Match ID, preventing duplicates.
- Profile Sync refreshes shared participant history without deleting permanent completed matches.
