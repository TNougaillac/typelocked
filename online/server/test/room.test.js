import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

const KEY = "test-group-key";
const RULES = { nuzlocke: "required", typeDraw: "free", sameType: true };
const auth = (key = KEY) => ({ Authorization: `Bearer ${key}` });

function call(path, init = {}) {
  return exports.default.fetch(`https://salons.test${path}`, { ...init, headers: { ...auth(), ...init.headers } });
}

async function createRoom(name = "Tom", secret = "secret-of-tom-0001", rules = RULES) {
  const res = await call("/rooms", { method: "POST", body: JSON.stringify({ name, secret, rules }) });
  expect(res.status).toBe(201);
  return (await res.json()).code;
}

// A connected player: every message received is queued, next() waits for one of a type.
async function connect(code, name, secret) {
  const res = await call(`/rooms/${code}/ws?name=${encodeURIComponent(name)}&secret=${secret}`, { headers: { Upgrade: "websocket" } });
  expect(res.status).toBe(101);
  const ws = res.webSocket;
  const queue = [];
  const waiters = [];
  ws.addEventListener("message", (e) => {
    queue.push(JSON.parse(e.data));
    waiters.splice(0).forEach((w) => w());
  });
  ws.accept();
  return {
    ws,
    send: (msg) => ws.send(JSON.stringify(msg)),
    async next(type) {
      for (;;) {
        const i = queue.findIndex((m) => m.type === type);
        if (i >= 0) return queue.splice(i, 1)[0];
        await new Promise((resolve) => waiters.push(resolve));
      }
    },
  };
}

describe("room server", () => {
  it("refuses requests without the group key", async () => {
    const res = await exports.default.fetch("https://salons.test/rooms", { method: "POST", headers: auth("wrong-key-0000") });
    expect(res.status).toBe(401);
  });

  it("creates a room with a short code and its rules", async () => {
    const code = await createRoom();
    expect(code).toMatch(/^[A-HJ-KM-NP-Z2-9]{6}$/);
    const info = await (await call(`/rooms/${code}`)).json();
    expect(info.rules).toEqual(RULES);
    expect(info.started).toBe(false);
    expect(info.players).toEqual([expect.objectContaining({ name: "Tom", host: true, connected: false })]);
  });

  it("rejects unknown rules", async () => {
    const res = await call("/rooms", { method: "POST", body: JSON.stringify({ name: "Tom", secret: "secret-of-tom-0001", rules: { nuzlocke: "maybe" } }) });
    expect(res.status).toBe(400);
  });

  it("keeps two players with the same nickname apart", async () => {
    const code = await createRoom("Léo", "secret-of-leo-0001");
    const a = await connect(code, "Léo", "secret-of-leo-0001");
    const b = await connect(code, "Léo", "secret-of-leo-0002");
    const welcomeA = await a.next("welcome");
    const welcomeB = await b.next("welcome");
    expect(welcomeA.you).not.toBe(welcomeB.you);
    expect(welcomeA.you).toBe(welcomeA.host);
  });

  it("gives the same seed to every player and says when all are connected", async () => {
    const code = await createRoom();
    const tom = await connect(code, "Tom", "secret-of-tom-0001");
    const seedTom = (await tom.next("welcome")).seed;
    expect((await tom.next("presence")).allConnected).toBe(true);
    const leo = await connect(code, "Léo", "secret-of-leo-0001");
    expect((await leo.next("welcome")).seed).toBe(seedTom);
    const presence = await tom.next("presence");
    expect(presence.players.map((p) => p.name)).toEqual(["Tom", "Léo"]);
    expect(presence.allConnected).toBe(true);
    leo.ws.close(1000);
    const after = await tom.next("presence");
    expect(after.allConnected).toBe(false);
    expect(after.players.find((p) => p.name === "Léo").connected).toBe(false);
  });

  it("relays a player's events to the others only", async () => {
    const code = await createRoom();
    const tom = await connect(code, "Tom", "secret-of-tom-0001");
    const leo = await connect(code, "Léo", "secret-of-leo-0001");
    const tomId = (await tom.next("welcome")).you;
    tom.send({ type: "event", data: { kind: "seal", type: "FIRE" } });
    const event = await leo.next("event");
    expect(event).toEqual({ type: "event", from: tomId, data: { kind: "seal", type: "FIRE" } });
  });

  it("lets only the host start, and only when everyone is there", async () => {
    const code = await createRoom();
    const tom = await connect(code, "Tom", "secret-of-tom-0001");
    const leo = await connect(code, "Léo", "secret-of-leo-0001");
    leo.send({ type: "start" });
    expect((await leo.next("error")).error).toBe("not_host");
    tom.send({ type: "start" });
    const start = await leo.next("start");
    expect(start.rules).toEqual(RULES);
    expect(start.seed).toBe((await tom.next("welcome")).seed);
    const late = await call(`/rooms/${code}/ws?name=Zoe&secret=secret-of-zoe-0001`, { headers: { Upgrade: "websocket" } });
    expect(late.status).toBe(409);
  });

  it("lets a known player come back after the start", async () => {
    const code = await createRoom();
    const tom = await connect(code, "Tom", "secret-of-tom-0001");
    tom.send({ type: "start" });
    await tom.next("start");
    tom.ws.close(1000);
    const again = await connect(code, "Tom", "secret-of-tom-0001");
    expect((await again.next("welcome")).started).toBe(true);
  });

  it("keeps each player's last progress for the launcher", async () => {
    const code = await createRoom();
    const tom = await connect(code, "Tom", "secret-of-tom-0001");
    const leo = await connect(code, "Léo", "secret-of-leo-0001");
    tom.send({ type: "event", data: { kind: "status", seals: 2, score: 230 } });
    tom.send({ type: "event", data: { kind: "news", what: "seal", count: 2 } });
    await leo.next("event");
    await leo.next("event");
    const info = await (await call(`/rooms/${code}`)).json();
    expect(info.players.find((p) => p.name === "Tom").status).toEqual({ kind: "status", seals: 2, score: 230 });
    expect(info.players.find((p) => p.name === "Léo").status).toBe(null);
  });
});
