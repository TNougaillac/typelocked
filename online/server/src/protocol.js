// Shared rules of the room protocol: what a client may send and how rooms
// are named. Kept free of Worker APIs so it can be read on its own.

export const MAX_PLAYERS = 8;
export const MAX_NAME = 16;
export const MIN_SECRET = 16;
export const MAX_EVENT_BYTES = 8192;
// A disconnected player can be removed by the host after this long (#145).
export const KICK_AFTER_MS = 5 * 60 * 1000;
export const SEED_MAX = 1_000_000; // same range as MapProceduralGenerator's rand(1_000_000)

// No 0/O, 1/I/L: the code is read aloud between friends.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 6;

const RULE_CHOICES = {
  nuzlocke: ["required", "free"], // Nuzlocke imposed, or each player's choice
  typeDraw: ["required", "free"], // type drawn at random imposed, or each player's choice
  sameType: [true, false],        // one type for the whole room, or one per player
};

export function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
}

export function isCode(code) {
  return typeof code === "string" && code.length === CODE_LENGTH &&
    [...code].every((c) => CODE_ALPHABET.includes(c));
}

export function randomSeed() {
  return crypto.getRandomValues(new Uint32Array(1))[0] % SEED_MAX;
}

// The room rules, or null when one is missing or unknown.
export function parseRules(rules) {
  if (!rules || typeof rules !== "object") return null;
  const parsed = {};
  for (const [key, choices] of Object.entries(RULE_CHOICES)) {
    if (!choices.includes(rules[key])) return null;
    parsed[key] = rules[key];
  }
  return parsed;
}

// The trimmed nickname, or null.
export function parseName(name) {
  if (typeof name !== "string") return null;
  const trimmed = name.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_NAME ? trimmed : null;
}

export function isSecret(secret) {
  return typeof secret === "string" && secret.length >= MIN_SECRET && secret.length <= 128;
}

// A player's id in a room: two friends with the same nickname stay apart
// because their secrets differ, and the secret itself is never sent back.
export async function playerId(code, secret) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${code}:${secret}`));
  return Array.from(new Uint8Array(digest).slice(0, 6), (b) => b.toString(16).padStart(2, "0")).join("");
}

export function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
}
