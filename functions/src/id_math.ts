export const FIRST_PLAYER_ID = 100_000;
export const DEFAULT_ID_BLOCK_SIZE = 1_024;

export function playerIdForOffset(offset: number): string {
  if (!Number.isSafeInteger(offset) || offset < 0) {
    throw new RangeError("offset must be a non-negative safe integer");
  }
  const value = FIRST_PLAYER_ID + offset;
  if (!Number.isSafeInteger(value)) {
    throw new RangeError("player ID space exhausted");
  }
  return value.toString();
}

export function blockEnd(start: number, size = DEFAULT_ID_BLOCK_SIZE): number {
  if (!Number.isSafeInteger(start) || start < FIRST_PLAYER_ID) {
    throw new RangeError("invalid block start");
  }
  if (!Number.isSafeInteger(size) || size < 1) {
    throw new RangeError("invalid block size");
  }
  const end = start + size - 1;
  if (!Number.isSafeInteger(end)) throw new RangeError("ID space exhausted");
  return end;
}
