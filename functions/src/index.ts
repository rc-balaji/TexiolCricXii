import { randomBytes, randomInt, scryptSync, timingSafeEqual, createHash } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { DEFAULT_ID_BLOCK_SIZE, FIRST_PLAYER_ID, blockEnd } from "./id_math.js";

initializeApp();
setGlobalOptions({ region: "asia-south1", maxInstances: 100 });

const db = getFirestore();
const auth = getAuth();
const allocatorRef = db.doc("system/playerIdAllocator");

async function setPlayerClaim(uid: string, playerId: string): Promise<void> {
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {
    ...(user.customClaims ?? {}),
    playerId,
  });
}

type IdBlock = { next: number; end: number };
let activeBlock: IdBlock | undefined;
let reservation: Promise<void> | undefined;

function requiredText(value: unknown, field: string, min = 1, max = 160): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const clean = value.trim();
  if (clean.length < min || clean.length > max) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain ${min}-${max} characters.`,
    );
  }
  return clean;
}

function optionalText(value: unknown, max = 320): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || value.trim().length > max) {
    throw new HttpsError("invalid-argument", "Invalid text value.");
  }
  return value.trim();
}

function stringList(
  value: unknown,
  field: string,
  maxItems: number,
  maxItemLength: number,
): string[] {
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return [...new Set(value.map((item) => requiredText(item, field, 1, maxItemLength)))];
}

function numericPlayerId(value: unknown): string {
  const id = requiredText(value, "playerId", 6, 16);
  if (!/^\d+$/.test(id)) {
    throw new HttpsError("invalid-argument", "Player ID must contain digits only.");
  }
  return id;
}

function validatePassword(value: unknown, temporary = false): string {
  const password = requiredText(value, "password", 8, 128);
  if (temporary && !/^\d+$/.test(password)) {
    throw new HttpsError(
      "invalid-argument",
      "A temporary password must contain digits only.",
    );
  }
  return password;
}

function hashPassword(password: string): { hash: string; salt: string } {
  const salt = randomBytes(24).toString("hex");
  return {
    salt,
    hash: scryptSync(password, salt, 64).toString("hex"),
  };
}

function passwordMatches(password: string, salt: string, expected: string): boolean {
  const actual = scryptSync(password, salt, 64);
  const expectedBytes = Buffer.from(expected, "hex");
  return actual.length === expectedBytes.length && timingSafeEqual(actual, expectedBytes);
}

async function reserveBlock(): Promise<void> {
  const block = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(allocatorRef);
    const nextValue = snapshot.exists
      ? Number(snapshot.get("nextValue"))
      : FIRST_PLAYER_ID;
    const end = blockEnd(nextValue, DEFAULT_ID_BLOCK_SIZE);
    transaction.set(
      allocatorRef,
      {
        nextValue: end + 1,
        blockSize: DEFAULT_ID_BLOCK_SIZE,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { next: nextValue, end };
  });
  activeBlock = block;
}

async function ensureBlock(): Promise<void> {
  if (activeBlock && activeBlock.next <= activeBlock.end) return;
  reservation ??= reserveBlock().finally(() => {
    reservation = undefined;
  });
  await reservation;
}

async function allocatePlayerId(): Promise<string> {
  for (;;) {
    await ensureBlock();
    const block = activeBlock;
    if (!block) throw new HttpsError("internal", "ID block unavailable.");
    const id = (block.next++).toString();
    try {
      await db.doc(`playerIds/${id}`).create({
        state: "reserved",
        reservedAt: FieldValue.serverTimestamp(),
      });
      return id;
    } catch (error) {
      const code = (error as { code?: number | string }).code;
      if (code === 6 || code === "already-exists") continue;
      throw error;
    }
  }
}

function requireUid(authContext: { uid: string } | undefined): string {
  if (!authContext) throw new HttpsError("unauthenticated", "Sign in required.");
  return authContext.uid;
}

function requireRecentSignIn(
  authContext: { token: { auth_time?: number } } | undefined,
  maxAgeSeconds = 10 * 60,
): void {
  const authTime = authContext?.token.auth_time;
  const now = Math.floor(Date.now() / 1000);
  if (typeof authTime !== "number" || now - authTime > maxAgeSeconds) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in again before this security-sensitive change.",
    );
  }
}

async function playerIdForUid(uid: string): Promise<string> {
  const snapshot = await db.doc(`users/${uid}`).get();
  const id = snapshot.exists ? snapshot.get("playerId") : undefined;
  if (typeof id !== "string") {
    throw new HttpsError("failed-precondition", "Create a player profile first.");
  }
  return id;
}

function publicProfile(playerId: string, name: string, ownerUid: string | null) {
  return {
    playerId,
    ownerUid,
    name,
    claimed: ownerUid != null,
    archived: false,
    battingStyle: "rightHanded",
    bowlingStyles: ["Right-arm medium"],
    avatarSource: "preset",
    avatarPreset: randomInt(1, 6),
    stats: {},
    teamStats: {},
    joinedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export const ensurePlayerProfile = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const name = requiredText(request.data?.name, "name", 2, 80);
    const contactEmail = optionalText(request.data?.contactEmail, 254);
    const password = validatePassword(request.data?.idPassword);
    const userRef = db.doc(`users/${uid}`);
    const existing = await userRef.get();
    const existingId = existing.exists ? existing.get("playerId") : undefined;
    if (typeof existingId === "string") {
      await setPlayerClaim(uid, existingId);
      return { playerId: existingId };
    }

    const allocatedId = await allocatePlayerId();
    const secret = hashPassword(password);
    let resolvedId = allocatedId;
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(userRef);
      const currentId = current.exists ? current.get("playerId") : undefined;
      if (typeof currentId === "string") {
        resolvedId = currentId;
        return;
      }
      transaction.set(userRef, {
        playerId: allocatedId,
        contactEmail,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.doc(`players/${allocatedId}`),
        publicProfile(allocatedId, name, uid),
      );
      transaction.set(db.doc(`loginSecrets/${allocatedId}`), {
        uid,
        kind: "account",
        ...secret,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.doc(`playerIds/${allocatedId}`),
        { uid, state: "claimed", updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    });
    await setPlayerClaim(uid, resolvedId);
    return { playerId: resolvedId };
  },
);

export const createProvisionalPlayer = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const creatorUid = requireUid(request.auth);
    const creatorPlayerId = await playerIdForUid(creatorUid);
    const name = requiredText(request.data?.name, "name", 2, 80);
    const contactEmail = optionalText(request.data?.contactEmail, 254);
    const supplied = optionalText(request.data?.temporaryPassword, 128);
    const temporaryPassword = supplied == null
      ? Array.from({ length: 8 }, () => randomInt(0, 10)).join("")
      : validatePassword(supplied, true);
    const playerId = await allocatePlayerId();
    const secret = hashPassword(temporaryPassword);
    const batch = db.batch();
    batch.set(
      db.doc(`players/${playerId}`),
      {
        ...publicProfile(playerId, name, null),
        createdByPlayerId: creatorPlayerId,
      },
    );
    batch.set(db.doc(`loginSecrets/${playerId}`), {
      uid: null,
      kind: "provisional",
      ...secret,
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(
      db.doc(`playerIds/${playerId}`),
      {
        uid: null,
        state: "provisional",
        contactEmail,
        createdByUid: creatorUid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await batch.commit();
    return { playerId, temporaryPassword };
  },
);

export const updateProvisionalPlayer = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const creatorUid = requireUid(request.auth);
    const creatorPlayerId = await playerIdForUid(creatorUid);
    const playerId = numericPlayerId(request.data?.playerId);
    const rawProfile = request.data?.profile;
    const rawContacts = request.data?.contacts;
    if (
      rawProfile == null ||
      typeof rawProfile !== "object" ||
      Array.isArray(rawProfile) ||
      rawContacts == null ||
      typeof rawContacts !== "object" ||
      Array.isArray(rawContacts)
    ) {
      throw new HttpsError("invalid-argument", "Profile details are required.");
    }
    const profile = rawProfile as Record<string, unknown>;
    const contacts = rawContacts as Record<string, unknown>;
    const name = requiredText(profile.name, "name", 2, 80);
    const battingStyle = requiredText(profile.battingStyle, "battingStyle", 1, 40);
    if (!["rightHanded", "leftHanded"].includes(battingStyle)) {
      throw new HttpsError("invalid-argument", "Invalid batting style.");
    }
    const avatarSource = requiredText(profile.avatarSource, "avatarSource", 1, 40);
    if (!["preset", "customUrl", "google", "facebook"].includes(avatarSource)) {
      throw new HttpsError("invalid-argument", "Invalid avatar source.");
    }
    const avatarPreset = Number(profile.avatarPreset);
    if (!Number.isInteger(avatarPreset) || avatarPreset < 1 || avatarPreset > 5) {
      throw new HttpsError("invalid-argument", "Invalid avatar preset.");
    }
    const age = profile.age == null ? null : Number(profile.age);
    if (age != null && (!Number.isInteger(age) || age < 0 || age > 130)) {
      throw new HttpsError("invalid-argument", "Invalid age.");
    }
    const contactData: Record<string, {
      value: string | null;
      visibility: string;
      audienceIds: string[];
    }> = {};
    for (const field of ["email", "phone", "whatsapp", "location"]) {
      const raw = contacts[field];
      if (raw == null || typeof raw !== "object" || Array.isArray(raw)) continue;
      const item = raw as Record<string, unknown>;
      const visibility = requiredText(item.visibility, `${field} visibility`, 1, 40);
      if (![
        "onlyMe",
        "friends",
        "selectedFriends",
        "everyoneExceptSelected",
        "everyone",
      ].includes(visibility)) {
        throw new HttpsError("invalid-argument", `Invalid ${field} visibility.`);
      }
      const audienceIds = stringList(item.audienceIds ?? [], `${field} audience`, 500, 16);
      if (audienceIds.some((id) => !/^\d{6,}$/.test(id))) {
        throw new HttpsError("invalid-argument", `Invalid ${field} audience.`);
      }
      contactData[field] = {
        value: optionalText(item.value, field === "email" ? 254 : 160),
        visibility,
        audienceIds,
      };
    }
    const playerRef = db.doc(`players/${playerId}`);
    const idRef = db.doc(`playerIds/${playerId}`);
    await db.runTransaction(async (transaction) => {
      const player = await transaction.get(playerRef);
      if (
        !player.exists ||
        player.get("ownerUid") != null ||
        player.get("createdByPlayerId") !== creatorPlayerId ||
        player.get("deletionPending") === true
      ) {
        throw new HttpsError(
          "permission-denied",
          "Only the creator can edit this unclaimed player.",
        );
      }
      transaction.update(playerRef, {
        name,
        bio: optionalText(profile.bio, 160),
        age,
        instagramHandle: optionalText(profile.instagramHandle, 120),
        facebookUrl: optionalText(profile.facebookUrl, 320),
        battingStyle,
        bowlingStyles: stringList(profile.bowlingStyles, "bowlingStyles", 12, 60),
        customBowlingStyle: optionalText(profile.customBowlingStyle, 80),
        avatarSource,
        avatarPreset,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        idRef,
        {
          contactEmail: contactData.email?.value ?? null,
          provisionalContacts: contactData,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    return { updated: true };
  },
);

async function routePendingSocialItems(playerId: string, uid: string): Promise<void> {
  const [requests, notifications] = await Promise.all([
    db
      .collection("friendRequests")
      .where("toPlayerId", "==", playerId)
      .where("status", "==", "pending")
      .get(),
    db
      .collection("notifications")
      .where("recipientPlayerId", "==", playerId)
      .get(),
  ]);
  const writer = db.bulkWriter();
  for (const document of requests.docs) {
    writer.update(document.ref, { toUid: uid });
  }
  for (const document of notifications.docs) {
    writer.update(document.ref, { recipientUid: uid });
  }
  await writer.close();
}

export const claimPlayer = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const playerId = numericPlayerId(request.data?.playerId);
    const password = validatePassword(request.data?.temporaryPassword, true);
    const rateLimitRef = await checkLoginRateLimit(
      `claim:${playerId}`,
      request.rawRequest.ip ?? "unknown",
    );
    const secretRef = db.doc(`loginSecrets/${playerId}`);
    const secretSnapshot = await secretRef.get();
    if (
      !secretSnapshot.exists ||
      secretSnapshot.get("kind") !== "provisional" ||
      !passwordMatches(
        password,
        String(secretSnapshot.get("salt")),
        String(secretSnapshot.get("hash")),
      )
    ) {
      throw new HttpsError("permission-denied", "Invalid claim details.");
    }

    await db.runTransaction(async (transaction) => {
      const playerRef = db.doc(`players/${playerId}`);
      const playerIdRef = db.doc(`playerIds/${playerId}`);
      const userRef = db.doc(`users/${uid}`);
      const [playerSnapshot, playerIdSnapshot, userSnapshot] = await Promise.all([
        transaction.get(playerRef),
        transaction.get(playerIdRef),
        transaction.get(userRef),
      ]);
      const ownedPlayerId = userSnapshot.exists
        ? userSnapshot.get("playerId")
        : undefined;
      if (typeof ownedPlayerId === "string" && ownedPlayerId !== playerId) {
        throw new HttpsError(
          "already-exists",
          "This account already owns another Player ID.",
        );
      }
      if (!playerSnapshot.exists || playerSnapshot.get("ownerUid") != null) {
        throw new HttpsError("already-exists", "This Player ID is already claimed.");
      }
      if (playerSnapshot.get("deletionPending") === true) {
        throw new HttpsError("not-found", "This provisional player was deleted.");
      }
      const contactEmail = playerIdSnapshot.exists
        ? playerIdSnapshot.get("contactEmail")
        : undefined;
      const provisionalContacts = playerIdSnapshot.exists
        ? playerIdSnapshot.get("provisionalContacts") as unknown
        : undefined;
      transaction.set(
        userRef,
        {
          playerId,
          contactEmail: typeof contactEmail === "string" ? contactEmail : null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      transaction.update(playerRef, {
        ownerUid: uid,
        claimed: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(secretRef, {
        uid,
        kind: "account",
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        playerIdRef,
        {
          uid,
          state: "claimed",
          contactEmail: FieldValue.delete(),
          provisionalContacts: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      const savedContacts = provisionalContacts != null &&
        typeof provisionalContacts === "object" &&
        !Array.isArray(provisionalContacts)
        ? provisionalContacts as Record<string, unknown>
        : {};
      if (Object.keys(savedContacts).length === 0 && typeof contactEmail === "string") {
        savedContacts.email = {
          value: contactEmail,
          visibility: "onlyMe",
          audienceIds: [],
        };
      }
      for (const field of ["email", "phone", "whatsapp", "location"]) {
        const raw = savedContacts[field];
        if (raw == null || typeof raw !== "object" || Array.isArray(raw)) continue;
        const contact = raw as Record<string, unknown>;
        const value = contact.value;
        if (typeof value !== "string" || value.length === 0) continue;
        transaction.set(db.doc(`players/${playerId}/contactFields/${field}`), {
          ownerUid: uid,
          ownerPlayerId: playerId,
          value,
          visibility: contact.visibility ?? "onlyMe",
          audienceIds: contact.audienceIds ?? [],
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    await setPlayerClaim(uid, playerId);
    await routePendingSocialItems(playerId, uid);
    await rateLimitRef.delete();
    return { playerId };
  },
);

export const deleteProvisionalPlayer = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const creatorUid = requireUid(request.auth);
    const creatorPlayerId = await playerIdForUid(creatorUid);
    const playerId = numericPlayerId(request.data?.playerId);
    const playerRef = db.doc(`players/${playerId}`);
    const idRef = db.doc(`playerIds/${playerId}`);
    await db.runTransaction(async (transaction) => {
      const player = await transaction.get(playerRef);
      if (!player.exists) {
        throw new HttpsError("not-found", "Provisional player not found.");
      }
      if (
        player.get("ownerUid") != null ||
        player.get("createdByPlayerId") !== creatorPlayerId
      ) {
        throw new HttpsError(
          "permission-denied",
          "Only the creator can delete this unclaimed player.",
        );
      }
      transaction.update(playerRef, {
        deletionPending: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        idRef,
        { state: "deleting", updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    });
    await db.recursiveDelete(playerRef);
    const deleted = new Set<string>();
    await Promise.all([
      deleteQuery(
        db.collection("friendRequests").where("toPlayerId", "==", playerId),
        deleted,
      ),
      deleteQuery(
        db.collection("friendRequests").where("fromPlayerId", "==", playerId),
        deleted,
      ),
      deleteQuery(
        db.collection("notifications").where("recipientPlayerId", "==", playerId),
        deleted,
      ),
    ]);
    const batch = db.batch();
    batch.delete(idRef);
    batch.delete(db.doc(`loginSecrets/${playerId}`));
    await batch.commit();
    return { deleted: true };
  },
);

async function checkLoginRateLimit(playerId: string, ip: string) {
  const key = createHash("sha256").update(`${playerId}:${ip}`).digest("hex");
  const ref = db.doc(`loginRateLimits/${key}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const now = Timestamp.now();
    const resetAt = snapshot.exists
      ? snapshot.get("resetAt") as Timestamp | undefined
      : undefined;
    const active = resetAt != null && resetAt.toMillis() > now.toMillis();
    const attempts = active ? Number(snapshot.get("attempts") ?? 0) : 0;
    if (attempts >= 10) {
      throw new HttpsError("resource-exhausted", "Too many login attempts. Try later.");
    }
    transaction.set(ref, {
      attempts: attempts + 1,
      resetAt: active
        ? resetAt
        : Timestamp.fromMillis(now.toMillis() + 15 * 60 * 1000),
      updatedAt: now,
    });
  });
  return ref;
}

export const loginWithPlayerId = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const playerId = numericPlayerId(request.data?.playerId);
    const password = validatePassword(request.data?.password);
    const ip = request.rawRequest.ip ?? "unknown";
    const rateLimitRef = await checkLoginRateLimit(playerId, ip);
    const snapshot = await db.doc(`loginSecrets/${playerId}`).get();
    const uid = snapshot.exists ? snapshot.get("uid") : undefined;
    if (
      !snapshot.exists ||
      snapshot.get("kind") !== "account" ||
      typeof uid !== "string" ||
      !passwordMatches(
        password,
        String(snapshot.get("salt")),
        String(snapshot.get("hash")),
      )
    ) {
      throw new HttpsError("permission-denied", "Invalid Player ID or password.");
    }
    await rateLimitRef.delete();
    return { customToken: await auth.createCustomToken(uid, { playerId }) };
  },
);

export const changePlayerIdPassword = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    requireRecentSignIn(request.auth);
    const playerId = await playerIdForUid(uid);
    const password = validatePassword(request.data?.password);
    await db.doc(`loginSecrets/${playerId}`).set(
      {
        uid,
        kind: "account",
        ...hashPassword(password),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { changed: true };
  },
);

export const sendFriendRequest = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const fromUid = requireUid(request.auth);
    const fromPlayerId = await playerIdForUid(fromUid);
    const toPlayerId = numericPlayerId(request.data?.targetPlayerId);
    if (fromPlayerId === toPlayerId) {
      throw new HttpsError("invalid-argument", "You cannot friend yourself.");
    }
    const target = await db.doc(`playerIds/${toPlayerId}`).get();
    const targetState = target.exists ? target.get("state") : undefined;
    if (!target.exists || !["provisional", "claimed"].includes(String(targetState))) {
      throw new HttpsError("not-found", "Player ID not found.");
    }
    const toUid = target.get("uid");
    const pairKey = [fromPlayerId, toPlayerId].sort().join("_");
    const requestRef = db.doc(`friendRequests/${pairKey}`);
    const friendshipRef = db.doc(`friendships/${pairKey}`);
    const notificationRef = db.collection("notifications").doc();
    await db.runTransaction(async (transaction) => {
      const [existingRequest, friendship] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(friendshipRef),
      ]);
      if (friendship.exists) {
        throw new HttpsError("already-exists", "This player is already your friend.");
      }
      if (existingRequest.exists && existingRequest.get("status") === "pending") {
        throw new HttpsError("already-exists", "A friend request is already pending.");
      }
      transaction.set(requestRef, {
        fromUid,
        fromPlayerId,
        toUid: typeof toUid === "string" ? toUid : null,
        toPlayerId,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        recipientUid: typeof toUid === "string" ? toUid : null,
        recipientPlayerId: toPlayerId,
        type: "friendRequest",
        requestId: requestRef.id,
        fromPlayerId,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { requestId: requestRef.id };
  },
);

export const respondFriendRequest = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const playerId = await playerIdForUid(uid);
    const requestId = requiredText(request.data?.requestId, "requestId", 8, 160);
    const accept = request.data?.accept === true;
    const requestRef = db.doc(`friendRequests/${requestId}`);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(requestRef);
      if (!snapshot.exists || snapshot.get("status") !== "pending") {
        throw new HttpsError("not-found", "Pending request not found.");
      }
      if (snapshot.get("toPlayerId") !== playerId) {
        throw new HttpsError("permission-denied", "Not your friend request.");
      }
      transaction.update(requestRef, {
        status: accept ? "accepted" : "rejected",
        respondedAt: FieldValue.serverTimestamp(),
      });
      if (accept) {
        const fromPlayerId = String(snapshot.get("fromPlayerId"));
        const key = [fromPlayerId, playerId].sort().join("_");
        transaction.set(db.doc(`friendships/${key}`), {
          playerIds: [fromPlayerId, playerId],
          uids: [snapshot.get("fromUid"), uid],
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.set(db.doc(`players/${fromPlayerId}/friends/${playerId}`), {
          playerId,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.set(db.doc(`players/${playerId}/friends/${fromPlayerId}`), {
          playerId: fromPlayerId,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection("notifications").doc(), {
          recipientUid: snapshot.get("fromUid"),
          recipientPlayerId: fromPlayerId,
          type: "friendAccepted",
          requestId,
          fromPlayerId: playerId,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { status: accept ? "accepted" : "rejected" };
  },
);

export const removeFriend = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const playerId = await playerIdForUid(uid);
    const friendPlayerId = numericPlayerId(request.data?.friendPlayerId);
    const key = [playerId, friendPlayerId].sort().join("_");
    const friendshipRef = db.doc(`friendships/${key}`);
    const friendship = await friendshipRef.get();
    const playerIds = friendship.exists ? friendship.get("playerIds") : null;
    if (!Array.isArray(playerIds) || !playerIds.includes(playerId)) {
      throw new HttpsError("not-found", "Friendship not found.");
    }
    const batch = db.batch();
    batch.delete(friendshipRef);
    batch.delete(db.doc(`players/${playerId}/friends/${friendPlayerId}`));
    batch.delete(db.doc(`players/${friendPlayerId}/friends/${playerId}`));
    await batch.commit();
    return { removed: true };
  },
);

export const markNotificationRead = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const notificationId = requiredText(
      request.data?.notificationId,
      "notificationId",
      8,
      160,
    );
    const ref = db.doc(`notifications/${notificationId}`);
    const snapshot = await ref.get();
    if (!snapshot.exists || snapshot.get("recipientUid") !== uid) {
      throw new HttpsError("not-found", "Notification not found.");
    }
    await ref.update({ read: true, readAt: FieldValue.serverTimestamp() });
    return { read: true };
  },
);

async function deleteQuery(
  query: FirebaseFirestore.Query,
  deletedPaths: Set<string>,
): Promise<void> {
  for (;;) {
    const snapshot = await query.limit(400).get();
    if (snapshot.empty) return;
    const batch = db.batch();
    let changed = false;
    for (const document of snapshot.docs) {
      if (deletedPaths.has(document.ref.path)) continue;
      deletedPaths.add(document.ref.path);
      batch.delete(document.ref);
      changed = true;
    }
    if (changed) {
      await batch.commit();
    } else {
      return;
    }
  }
}

export const resetMyPlayerData = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    const playerId = await playerIdForUid(uid);
    const friendshipSnapshot = await db
      .collection("friendships")
      .where("uids", "array-contains", uid)
      .get();
    const edgeWriter = db.bulkWriter();
    for (const friendship of friendshipSnapshot.docs) {
      const ids = friendship.get("playerIds") as unknown;
      if (!Array.isArray(ids)) continue;
      for (const otherId of ids.map(String).filter((id) => id !== playerId)) {
        edgeWriter.delete(db.doc(`players/${playerId}/friends/${otherId}`));
        edgeWriter.delete(db.doc(`players/${otherId}/friends/${playerId}`));
      }
    }
    await edgeWriter.close();
    const deleted = new Set<string>();
    await Promise.all([
      deleteQuery(db.collection("friendRequests").where("fromUid", "==", uid), deleted),
      deleteQuery(db.collection("friendRequests").where("toUid", "==", uid), deleted),
      deleteQuery(db.collection("notifications").where("recipientUid", "==", uid), deleted),
      deleteQuery(db.collection("friendships").where("uids", "array-contains", uid), deleted),
    ]);
    await db.doc(`users/${uid}/private/state`).delete();
    await db.doc(`players/${playerId}`).set(
      {
        stats: {},
        teamStats: {},
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { reset: true };
  },
);

export const deleteMyAccountData = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = requireUid(request.auth);
    requireRecentSignIn(request.auth);
    const userRef = db.doc(`users/${uid}`);
    const playerId = await playerIdForUid(uid);
    const friendshipSnapshot = await db
      .collection("friendships")
      .where("uids", "array-contains", uid)
      .get();
    const edgeWriter = db.bulkWriter();
    for (const friendship of friendshipSnapshot.docs) {
      const ids = friendship.get("playerIds") as unknown;
      if (!Array.isArray(ids)) continue;
      for (const otherId of ids.map(String).filter((id) => id !== playerId)) {
        edgeWriter.delete(db.doc(`players/${otherId}/friends/${playerId}`));
      }
    }
    await edgeWriter.close();
    const deleted = new Set<string>();
    await Promise.all([
      deleteQuery(db.collection("friendRequests").where("fromUid", "==", uid), deleted),
      deleteQuery(db.collection("friendRequests").where("toUid", "==", uid), deleted),
      deleteQuery(db.collection("notifications").where("recipientUid", "==", uid), deleted),
      deleteQuery(db.collection("friendships").where("uids", "array-contains", uid), deleted),
    ]);
    await db.recursiveDelete(userRef);
    await db.recursiveDelete(db.doc(`players/${playerId}`));
    const batch = db.batch();
    batch.delete(db.doc(`playerIds/${playerId}`));
    batch.delete(db.doc(`loginSecrets/${playerId}`));
    await batch.commit();
    await auth.deleteUser(uid);
    return { deleted: true };
  },
);
