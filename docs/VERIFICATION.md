# CricXii v1.0.0 verification

Final release verification should run in GitHub Actions:

1. `flutter analyze --no-fatal-infos`
2. `flutter test`
3. `flutter build apk --release ...`

Additional V1 tests cover over conversion and bowling-plan edge cases, including two-player all-overs assignment, no self-bowling, adjacent-over diversity and workload balancing.
