import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { loadIdentity } from "../src/identity.js";
import { startLocalServer } from "../src/local-server.js";
import { RoomClient } from "../src/room-client.js";

// Stands in for the server's WebSocket: records what is sent.
class FakeWebSocket {
  static last = null;
  constructor(url, options) {
    Object.assign(this, { url, options, sent: [], readyState: 0 });
    FakeWebSocket.last = this;
  }
  open() {
    this.readyState = 1;
    this.onopen?.();
  }
  send(text) {
    this.sent.push(JSON.parse(text));
  }
  serverSends(msg) {
    this.onmessage({ data: JSON.stringify(msg) });
  }
  close() {}
}

const IDENTITY = { server: "https://salons.test", groupKey: "key-0123456789", name: "Tom", secret: "s".repeat(48) };

test("the identity keeps its secret and takes a new nickname", () => {
  const dir = mkdtempSync(join(tmpdir(), "pont-"));
  assert.throws(() => loadIdentity(dir));
  const first = loadIdentity(dir, "Tom");
  const again = loadIdentity(dir, "Tommy");
  assert.equal(again.secret, first.secret);
  assert.equal(again.name, "Tommy");
  assert.equal(loadIdentity(dir).name, "Tommy");
});

test("the client follows the room and sends the group key", () => {
  const client = new RoomClient(IDENTITY, { WebSocketImpl: FakeWebSocket });
  client.connect("ABC234");
  const ws = FakeWebSocket.last;
  assert.equal(ws.url, `wss://salons.test/rooms/ABC234/ws?name=Tom&secret=${IDENTITY.secret}`);
  assert.equal(ws.options.headers.Authorization, "Bearer key-0123456789");
  ws.open();
  ws.serverSends({ type: "welcome", you: "a1", host: "a1", seed: 42, rules: { nuzlocke: "free" }, started: false });
  ws.serverSends({ type: "presence", players: [{ id: "a1", name: "Tom", connected: true }], allConnected: true });
  ws.serverSends({ type: "start", seed: 42, rules: { nuzlocke: "free" } });
  assert.equal(client.room.started, true);
  assert.equal(client.room.allConnected, true);
  assert.equal(client.room.seed, 42);
});

test("events sent while disconnected leave once connected, in order", () => {
  const client = new RoomClient(IDENTITY, { WebSocketImpl: FakeWebSocket });
  client.connect("ABC234");
  client.publish({ kind: "seal", n: 1 });
  client.publish({ kind: "seal", n: 2 });
  FakeWebSocket.last.open();
  assert.deepEqual(FakeWebSocket.last.sent.map((m) => m.data.n), [1, 2]);
});

test("the game reads the room and the events, and publishes through the local service", async () => {
  const client = new RoomClient(IDENTITY, { WebSocketImpl: FakeWebSocket });
  client.connect("ABC234");
  const ws = FakeWebSocket.last;
  ws.open();
  ws.serverSends({ type: "welcome", you: "a1", host: "a1", seed: 7, started: true });
  ws.serverSends({ type: "event", from: "b2", data: { kind: "seal" } });
  ws.serverSends({ type: "event", from: "b2", data: { kind: "death" } });
  const server = await startLocalServer(client, 0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await (await fetch(`${base}/state`)).json()).room.seed, 7);
    const events = await (await fetch(`${base}/events?after=1`)).json();
    assert.deepEqual(events, { events: [{ n: 2, from: "b2", data: { kind: "death" } }], last: 2 });
    const posted = await fetch(`${base}/event`, { method: "POST", body: JSON.stringify({ data: { kind: "place", map: 3 } }) });
    assert.equal(posted.status, 204);
    assert.deepEqual(ws.sent.at(-1), { type: "event", data: { kind: "place", map: 3 } });
    assert.equal((await fetch(`${base}/event`, { method: "POST", body: "nope" })).status, 400);
  } finally {
    server.close();
  }
});
