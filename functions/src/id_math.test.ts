import assert from "node:assert/strict";
import test from "node:test";

import { blockEnd, playerIdForOffset } from "./id_math.js";

test("numeric IDs grow from 6 to 7, 8, 9 and 10 digits", () => {
  assert.equal(playerIdForOffset(0), "100000");
  assert.equal(playerIdForOffset(899_999), "999999");
  assert.equal(playerIdForOffset(900_000), "1000000");
  assert.equal(playerIdForOffset(9_900_000), "10000000");
  assert.equal(playerIdForOffset(99_900_000), "100000000");
  assert.equal(playerIdForOffset(999_900_000), "1000000000");
});

test("the billionth allocation remains a numeric unique ID", () => {
  const id = playerIdForOffset(999_999_999);
  assert.equal(id, "1000099999");
  assert.match(id, /^\d+$/);
});

test("reserved blocks do not overlap", () => {
  const firstStart = 100_000;
  const firstEnd = blockEnd(firstStart);
  const secondStart = firstEnd + 1;
  assert.equal(firstEnd, 101_023);
  assert.equal(blockEnd(secondStart), 102_047);
});
