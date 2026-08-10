# CricXii v0.3.0 architecture

## Identity layers

CricXii deliberately separates transport identity from cricket identity.

### Firebase transport identity

Firebase Authentication is Anonymous-only. The Firebase UID is temporary infrastructure identity used by Firestore Security Rules. It is not shown as the CricXii account ID.

### CricXii account identity

The permanent application identity is the numeric `playerId`. The visible login is email/password stored as a salted verifier in `loginCredentials` and mapped to one Player ID.

A successful client login binds the current anonymous Firebase UID in `sessions/{uid}` to that Player ID. Normal Firestore rules then use the session mapping to determine the active player.

## Collections

| Path | Purpose |
| --- | --- |
| `loginCredentials/{emailHash}` | Login email + Player ID + salt/verifier |
| `players/{playerId}` | Basic/public profile and cricket summary |
| `sessions/{anonymousUid}` | Current transport UID -> Player ID |
| `accountStates/{playerId}` | Private serialized scorer/account state |
| `friendRequests/{pairId}` | Player-ID based request state |
| `notifications/{id}` | In-app activity for one recipient Player ID |
| `players/{id}/friends/{friendId}` | Accepted friendship edge |
| `players/{id}/contactFields/{field}` | Optional private/shareable phone, WhatsApp, location |

## Account creation

An eight-digit random Player ID is generated locally with `Random.secure()`. A Firestore transaction checks both the email credential document and Player ID document before atomically creating them. Collision retries are bounded.

Creating a player from Player Management uses the same full account transaction. The creator only keeps the new player's cricket profile locally; the other player's login email is not copied into the creator's player state.

## Friend requests

Request document ID is the two Player IDs sorted and joined. This gives one request record per player pair and makes pending-state reconciliation simple.

Refresh uses separate single-field queries for `toPlayerId` and `fromPlayerId`, then filters pending status in Dart. Notifications use `recipientPlayerId`. No continuous listener or polling is used.

## Navigation

`_AppGate` at the root chooses Login or Home from AppStore account state. Sign-out/delete clears the CricXii account state and pops Navigator routes to the first route, so the login page becomes visible immediately.
