# CricXii v1.5.0 — Live Team Flow & Mixed Daily Reports

CricXii is Texiol's Android-first local cricket scorer. Version `1.5.0+21` keeps the complete Singles experience and adds live Team batting choices, repeatable Super Overs, duplicate-prompt hardening and mixed Singles + Team daily reporting while remaining Firebase Spark-friendly.

## v1.5 highlights

- Team Match no longer asks for a fixed batting order before play. The selected roster supplies only the default opening pair; after a wicket, scoring pauses until the scorer chooses the next batter live.
- Live automatic prompts are mutually guarded so next batter, Last Player Standing and next bowler cannot open duplicate sheets/dialogs during rebuilds or cloud commits.
- A tied Team Match enters a Super Over flow: one over, two-wicket cap, same configured scoring/extras behavior, and another Super Over if the tie repeats. The host can also explicitly finish the match as tied.
- **Today Performance** is now completion-date based and can combine completed Singles and Team Matches. Users can filter All / Singles / Team, select any completed matches, choose PDF sections, preview, download and share.
- PDF title changes automatically to **Today Singles Performance**, **Today Team Match Performance**, or **Today Overall Performance** based on the selected matches.
- Team PDFs and daily mixed PDFs support repeated innings/Super Overs and adapt across multi-page player tables.

## Team Match features

- Flexible team sizes with no eleven-player cap.
- No fixed pre-match batting order: roster order provides default openers, then every wicket can choose the incoming batter live.
- Players-first setup with search: choose only the people playing now, then assign those players to teams.
- Optional shared **Joker** who appears for both teams, keeps separate per-side appearances and combined personal performance, and cannot bowl to themselves.
- Automatic editable names such as **Team Match 2**, **Team Match 3** and **Team Match 4**.
- Four start paths: timed in-app toss, physical/manual toss, skip toss, or let the previous winner choose Bat/Bowl.
- The in-app toss chooses a flipping team, assigns the other team as caller, spins for three seconds, accepts one Heads/Tails call only during the countdown, and reveals only after time ends.
- A missed timed call can restart the same toss, reset the full start flow, or skip directly to first-batting selection.
- Optional Wide, No-ball, Bye, Leg bye, Penalty and Free Hit rules configured per match.
- Individual bowling limits, over-level bowler selection, exhausted-quota blocking and optional consecutive overs.
- **Last Player Standing** prompt when one batter remains. In solo mode the same batter stays on strike after odd runs and over changes.
- Live player photos, score/target state, innings break, duplicate-safe automatic prompts, participant Watch mode and controller-device lease.
- Repeatable one-over, two-wicket **Super Overs** for tied Team Matches, including an explicit finish-as-tie fallback.
- Completed Team Match history and career stats for every participant, including cloud status on each history card.
- Result cloud sync is informative, not blocking: leave for Home at any time, then use **Sync now / Sync again** from result or History.
- Result offers a linked next match with either the same teams or a fresh player/team review. Linked matches retain series points.
- Point-based **Player of the Match**, **Player of Today** and **Player of the Series** awards.
- Profile stats and history use **All / Singles / Team Match** filters; Singles and Team records remain separate in storage.
- Adaptive multi-page Team Match PDF with result, toss, innings scorecards, batting, bowling, extras, fall of wickets, Joker and local rules.

## V1 Singles features

- Two scoring modes: **Ball Tracker** and **Direct Runs**.
- Match setup is over-based. CricXii setup convention supports half overs: **1.5 overs = 9 legal balls**, 2.5 = 15, etc.
- Ball Tracker stores every delivery, time, bowler, runs, extras and dismissal data and shows ball-by-ball turn history.
- Secret draw randomises both the phone-pass player order and face-down numbered-card positions.
- Optional **fixed balanced random bowling plan** after batting order is confirmed.
- Bowling planner keeps a full 6-ball over with one bowler, gives a final 3-ball half-over its own assignment, never assigns the batter, balances workload, and avoids unnecessary consecutive/cross-turn repeats when alternatives exist.
- Mid-over bowler replacement/injury flow changes future deliveries only; previously recorded deliveries retain their actual bowler.
- During a live match, add a player and reorder only the future/uncompleted batting queue.
- Local **Live Match** screen shows playing now, current bowler, live rankings, next order and recent balls.
- Balanced default points: run 1, wicket 5, catch 2, direct run-out 3, assisted run-out 1 each, stumping 2, not-out bonus 2.
- Custom point sets can be saved as presets and optionally made the default for future matches.
- Match creation, start, finish, score events, order changes, player additions and bowling changes are timestamped.
- Default match titles are generated by daypart and today's match count, e.g. `Evening Match 3`, and remain editable.
- Completed match has **Start new match with this rank order**.
- Date-wise **Performance** screen aggregates completed Singles + Team Matches by `completedAt`, with mixed selection and dynamic report titles.
- Premium one-page Match Scorecard PDF uses the CricXii app logo and player avatars.
- Daily Performance PDF is intentionally multi-page and includes CricXii branding, overall ranking, player cards and match timeline.


## Shared participant match history

Singles matches are no longer private to the creator device while they are in progress. Each match is shared canonically under `matches/{matchId}` from drawing through live scoring and completion, with `creatorPlayerId` as the host and `participantIds` as the read audience. Participants discover applicable matches on startup/foreground/manual refresh and open non-host matches in read-only Watch mode.

The host remains the only controller for scoring, undo, order changes, player additions, bowler replacement and cancellation. Watch mode uses a single match-document listener only while that screen is open. Completed matches remain the permanent source for each participant's applicable History and career-stat rebuild. Existing Build 15 creator-owned matches migrate using the same Match IDs.

Team Matches use the equivalent canonical `teamMatches/{matchId}` channel. The host owns setup/start choice, while the selected scorer can run live innings under the same single-device lease. Linked rematches carry `seriesId`, `previousMatchId` and `seriesMatchNumber` inside the canonical Team Match JSON. Participant discovery, Watch, completed History, manual retry and recent-first pagination apply to both match formats.

## v1.2 hardening

- Single scoring-controller device lease prevents two phones on the same account from silently overwriting each other. A confirmed **Take control** action is available for handover.
- The selected tracker/scorer can enter live score while host-only setup/order/player controls remain separate.
- Offline scoring persists locally and shows synced / waiting / retry state; revision checks prevent stale reconnects from overwriting newer canonical score.
- Equal primary scores use the **previous completed match rank/order** as the tie-break, then current batting order for players without prior rank.
- Daily performance uses match completion date, automatic Match N numbering counts only matches created by the current host, and online Match IDs are transactionally reserved.
- Mid-match participant additions publish to the shared audience; cancel/complete/undo/account-delete lifecycle transitions clean up participant Watch state correctly.
- Shared participant history is recent-first and paginated with **Load older matches** instead of unbounded loading.

## Account / Firebase foundation

The existing Fresh Start model remains unchanged: Firebase Anonymous Auth is an invisible Firebase session layer, while CricXii's app-facing Email + Password / numeric Player ID account data remains in the existing collections. Google/Facebook login, Player-ID claim flow and Cloud Functions are not reintroduced.

## Spark scope

V1 uses local scoring plus the existing Firestore sync model and does not add Cloud Functions. The remote shareable live-match link, public web viewer, live comments and Ask-to-Join workflow are deliberately deferred to a later release.

## Build

GitHub Actions bootstraps the Android shell, runs analyzer/tests and builds the release APK. Keep the `GOOGLE_SERVICES_JSON_BASE64` repository secret configured if Firebase sync is enabled. Do not commit `google-services.json` or private credentials.
