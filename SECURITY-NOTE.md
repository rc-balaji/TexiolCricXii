# Security note — Anonymous-only prototype

CricXii v1.0.0 deliberately uses Firebase Anonymous Authentication only because this build is being tested on the Firebase Spark plan with the requested simplified architecture.

The visible email/password account is implemented in the client and Firestore. Passwords are never stored in plain text. A random salt and an iterated SHA-256 verifier are stored in `loginCredentials`.

However, this is **not equivalent to trusted server-side authentication**. With no trusted backend and only anonymous Firebase identity, a determined attacker who can reproduce the client protocol has weaker barriers than they would with Firebase Email/Password Authentication or a server-side password verifier. Firestore rules protect normal app flows but cannot turn a client-side password comparison into a trusted authentication authority.

Use this architecture for prototype/testing and controlled users. Before a public production launch involving sensitive data, move credential verification to Firebase's supported account authentication or a trusted backend while keeping Player IDs and profile/social collections as the application identity layer.
## v1.2 device-control note

The controller lease and revision checks reduce accidental multi-device score races and stale overwrites. They are application/data-integrity hardening, not a replacement for trusted authentication. The current Anonymous Firebase transport identity plus client-side CricXii credential layer remains appropriate for prototype/controlled testing, not a claim of production-grade account security.


## v1.6.2 custom-avatar privacy note

A custom avatar's owner-supplied HTTPS source URL is private account data. It is stored only in the owner's local/account state and is not written to the public `players/{playerId}` document or shared match participant snapshots. When the URL is saved, the app downloads the image on the owner's device, renders a compact 128px thumbnail, and publishes only that rendered image data for other signed-in CricXii users to display. The avatar image itself is therefore shareable/profile-visible; the original source URL remains private.
