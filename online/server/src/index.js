// Entry point of the room server (ADR 0002). Checks the group key, then hands
// each room to its own Durable Object.
//
//   POST /rooms                  {name, secret, rules} -> 201 {code}
//   GET  /rooms/:code            -> {code, rules, players, started}
//   GET  /rooms/:code/ws?name=&secret=   WebSocket of a player
//
// Every request carries "Authorization: Bearer <GROUP_KEY>".
import { isCode, isSecret, json, parseName, parseRules, randomCode } from "./protocol.js";

export { Room } from "./room.js";

const CODE_ATTEMPTS = 5;

export default {
  async fetch(request, env) {
    if (!(await authorized(request, env))) return json({ error: "unauthorized" }, 401);
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts[0] !== "rooms") return json({ error: "not_found" }, 404);
    if (parts.length === 1 && request.method === "POST") return createRoom(request, env);
    if (parts.length < 2 || !isCode(parts[1])) return json({ error: "not_found" }, 404);
    const room = env.ROOMS.get(env.ROOMS.idFromName(parts[1]));
    if (parts.length === 2 && request.method === "GET") return room.fetch(new Request(`https://room/info?code=${parts[1]}`));
    if (parts.length === 3 && parts[2] === "ws") return room.fetch(new Request(`https://room/ws?code=${parts[1]}&${url.searchParams}`, request));
    return json({ error: "not_found" }, 404);
  },
};

async function createRoom(request, env) {
  const body = await request.json().catch(() => null);
  const name = parseName(body?.name);
  const rules = parseRules(body?.rules);
  if (!name || !isSecret(body?.secret) || !rules) return json({ error: "bad_request" }, 400);
  for (let i = 0; i < CODE_ATTEMPTS; i++) {
    const code = randomCode();
    const room = env.ROOMS.get(env.ROOMS.idFromName(code));
    const response = await room.fetch(new Request(`https://room/init?code=${code}`, {
      method: "POST",
      body: JSON.stringify({ name, secret: body.secret, rules }),
    }));
    if (response.status !== 409) return response; // 409: the code is taken, draw another
  }
  return json({ error: "no_free_code" }, 503);
}

async function authorized(request, env) {
  const given = (request.headers.get("Authorization") || "").replace(/^Bearer /, "");
  const expected = env.GROUP_KEY || "";
  if (!expected || given.length !== expected.length) return false;
  const encoder = new TextEncoder();
  return crypto.subtle.timingSafeEqual(encoder.encode(given), encoder.encode(expected));
}
