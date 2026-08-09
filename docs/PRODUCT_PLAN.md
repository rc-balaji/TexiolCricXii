# CricXii product plan

## Product promise

CricXii makes a real local-cricket Singles match feel official without requiring an umpire or scorer. Players can use one shared phone, optionally track every ball, finish with a reliable ranking, and share a permanent scorecard.

## V1 rules locked from the product discussion

| Area | CricXii V1 decision |
|---|---|
| Format | Singles Match only; Team Match is a later update |
| Turn end | Wicket or configured legal-ball limit |
| 1.5 overs | Exactly 9 balls |
| Tracker ON | Store each delivery, including legal-ball state and extras |
| Tracker OFF | Enter only each player's final runs plus Out/Not Out and dismissal credits |
| Gang membership | A player has at most one home gang but can play with anyone |
| Roles | Creator is Leader; Leader can promote Co-leaders |
| Profile image | Generated colour/initial avatar; Instagram handle stored as a link, with no Firebase Storage upload in V1 |
| No-phone player | Anyone can create an unclaimed local profile and receive a Player ID plus temporary claim detail |
| Draw | Unique face-down card per player; earlier choices stay hidden; last card auto-assigns |
| Ranking | Match creator selects Runs-only or Overall points before start |
| Recovery | Undo final event, reset current turn, adjust pre-match order, or send current player later |
| Output | Final ranking, player breakdown, career history, share/save PDF |

## Dismissal credits

| Dismissal | Bowler wicket | Fielding credit |
|---|---:|---|
| Bowled, LBW, hit wicket | Yes | None |
| Caught | Yes | Catcher |
| Caught & bowled | Yes | Bowler also receives catch |
| Stumped | Yes | Wicketkeeper receives stumping |
| Direct run-out | No | One fielder receives direct run-out |
| Assisted run-out | No | Up to two fielders receive assisted run-out |
| Retired out | No | None |

## Delivery milestones

### Singles foundation — included here

- Local-first profiles, gang roles, friend list, match setup, secret draw
- Both scoring modes and deterministic scoring/points engine
- Match history, final rankings, PDF scorecard, undo/edit controls
- Firebase Android configuration, email/password authentication, private recovery
- Automated APK build

### Connected Singles

- Normalized Firestore player/gang/match documents
- Join by Match ID from another phone
- Transactional private draw across multiple devices
- Live event stream with creator/tracker authorization and conflict protection
- Secure Player-ID + temporary-password claim service
- Email/Google credential linking after claim
- Invitations, friend requests, and gang discovery

### Team Match

- Teams, innings, striker/non-striker, over changes, bowling spells
- Extras and wicket rules appropriate to team cricket
- Team result, net totals, and full innings scorecard

## Secure claim decision

A Player ID must not be mapped to an email in a publicly readable collection. Claiming an unclaimed profile therefore needs a small trusted backend that verifies a one-time secret, atomically attaches the Firebase UID, and invalidates the secret. The client and Firestore rules reserve this boundary instead of implementing an insecure shortcut.
