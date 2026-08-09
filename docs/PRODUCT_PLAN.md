# CricXii product plan

## Product promise

CricXii makes real local cricket official without requiring a dedicated scorer. Each person owns a durable player identity, can build a trusted local network, play from one shared phone, and keep permanent match records.

## Locked product decisions

| Area | Decision |
|---|---|
| Account ownership | One Firebase UID owns exactly one Player ID |
| Opponents on a phone | Independent cached players, not account-switch profiles |
| Player ID | Digits only, starting at 6 digits and growing to 7/8/9/10 as required |
| High-scale allocation | Trusted block allocator; no collection scan or random retry loop |
| No-phone player | Separate provisional account with a temporary numeric password that becomes the initial ID login |
| Friends | Explicit request and accept/reject; never auto-friend on registration |
| Contacts | Private by default with a visibility rule per field |
| DOB | Stored privately; age is calculated and published instead of raw DOB |
| Avatar | Five built-ins, linked provider photo, or private HTTPS URL |
| Instagram | Store normalized handle/link; do not scrape an unstable profile image URL |
| Team Match | Visible as Coming Soon; Singles and Team records remain separate |
| Singles turn end | Wicket or configured legal-ball limit |
| 1.5 overs | Exactly 9 legal balls |
| Tracker off | One final runs/out entry per batter, not fake ball history |

## v0.2 Player & Social foundation — included

- Numeric Player ID service and old-ID local migration
- Email, ID/password, Google, and credential-gated Facebook sign-in/linking
- Provisional creation, creator-authorized editing, secure claim, and claim-time contact transfer
- Profile, privacy, player management, reset, provider disconnect, and deletion screens
- Friend requests, notification routing/refresh, accepted friendships, player lookup
- Original CricXii launcher icon and five original avatars
- Normalized public/contact/social Firestore documents with backend-only secrets

## Next: connected match hardening

- Join a match from another phone using Match ID
- Creator/tracker permissions and event revision transactions
- Read-only live score subscriptions for other players
- Transactional multi-device secret draw
- Push notifications after in-app notifications are proven

## Later: Team Match

- Teams, innings, striker/non-striker, overs, bowling spells, extras, wickets
- Team result and full innings scorecard
- Separate Team career stats and history

## Security boundary

Player-ID passwords, the ID allocator, provisional claiming, friendships, and account deletion run only in trusted callable Functions. No Admin key or password hash is exposed to the app, and public Player ID documents never map directly to an email address.
