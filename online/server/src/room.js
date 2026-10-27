// One room of friends (Durable Object). It keeps the rules, the seed and the
// players, knows who is connected and relays each player's events to the
// others. WebSockets use the Hibernation API: an idle room costs nothing.
import { DurableObject } from "cloudflare:workers";
import { MAX_EVENT_BYTES, MAX_PLAYERS, isSecret, json, parseName, playerId, randomSeed } from "./protocol.js";

export class Room extends DurableObject {
  async fetch(request) {
    const url = new URL(request.url);
    const code = url.searchParams.get("code");
    switch (url.pathname) {
      case "/init": return this.init(code, await request.json());
      case "/info": return this.info();
      case "/ws": return this.join(request, code, url.searchParams);
      default: return json({ error: "not_found" }, 404);
    }
  }

  async init(code, { name, secret, rules }) {
    if (await this.ctx.storage.get("room")) return json({ error: "taken" }, 409);
    const hostId = await playerId(code, secret);
    await this.ctx.storage.put({
      room: { code, rules, seed: randomSeed(), hostId, started: false, createdAt: Date.now() },
      players: { [hostId]: { name } },
    });
    return json({ code }, 201);
  }

  async info() {
    const room = await this.ctx.storage.get("room");
    if (!room) return json({ error: "not_found" }, 404);
    const { code, rules, started } = room;
    return json({ code, rules, started, players: await this.presence() });
  }

  async join(request, code, params) {
    if (request.headers.get("Upgrade") !== "websocket") return json({ error: "websocket_expected" }, 426);
    const room = await this.ctx.storage.get("room");
    if (!room) return json({ error: "not_found" }, 404);
    const name = parseName(params.get("name"));
    const secret = params.get("secret");
    if (!name || !isSecret(secret)) return json({ error: "bad_request" }, 400);
    const id = await playerId(code, secret);
    const players = await this.ctx.storage.get("players");
    if (!players[id]) {
      if (room.started) return json({ error: "started" }, 409);
      if (Object.keys(players).length >= MAX_PLAYERS) return json({ error: "full" }, 409);
    }
    players[id] = { name };
    await this.ctx.storage.put("players", players);
    // A player who joins again (new launch, lost connection) replaces the old socket.
    for (const old of this.ctx.getWebSockets(id)) old.close(4000, "replaced");
    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server, [id]);
    server.serializeAttachment({ id });
    send(server, { type: "welcome", you: id, host: room.hostId, code, rules: room.rules, seed: room.seed, started: room.started });
    await this.broadcastPresence();
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const { id } = ws.deserializeAttachment();
    const size = typeof message === "string" ? new TextEncoder().encode(message).length : message.byteLength;
    if (size > MAX_EVENT_BYTES) return send(ws, { type: "error", error: "too_large" });
    let msg;
    try {
      msg = JSON.parse(typeof message === "string" ? message : new TextDecoder().decode(message));
    } catch {
      return send(ws, { type: "error", error: "bad_json" });
    }
    if (msg?.type === "event" && msg.data && typeof msg.data === "object") {
      return this.broadcast({ type: "event", from: id, data: msg.data }, ws);
    }
    if (msg?.type === "start") return this.start(ws, id);
    return send(ws, { type: "error", error: "unknown_type" });
  }

  // The host starts the game once every player of the room is connected.
  async start(ws, id) {
    const room = await this.ctx.storage.get("room");
    if (id !== room.hostId) return send(ws, { type: "error", error: "not_host" });
    if (room.started) return send(ws, { type: "error", error: "started" });
    if (!(await this.presence()).every((p) => p.connected)) return send(ws, { type: "error", error: "not_all_connected" });
    room.started = true;
    await this.ctx.storage.put("room", room);
    this.broadcast({ type: "start", seed: room.seed, rules: room.rules });
  }

  async webSocketClose(ws, code) {
    try {
      ws.close(code === 1005 ? 1000 : code, "closed");
    } catch {
      // Already closed by the runtime.
    }
    await this.broadcastPresence(ws);
  }

  async webSocketError(ws) {
    await this.broadcastPresence(ws);
  }

  // Players in join order, with who is connected (gone: a socket being closed).
  async presence(gone = null) {
    const room = await this.ctx.storage.get("room");
    const players = (await this.ctx.storage.get("players")) || {};
    return Object.entries(players).map(([id, { name }]) => ({
      id,
      name,
      host: id === room.hostId,
      connected: this.ctx.getWebSockets(id).some((ws) => ws !== gone && ws.readyState === WebSocket.OPEN),
    }));
  }

  async broadcastPresence(gone = null) {
    const players = await this.presence(gone);
    this.broadcast({ type: "presence", players, allConnected: players.every((p) => p.connected) }, gone);
  }

  broadcast(msg, except = null) {
    for (const ws of this.ctx.getWebSockets()) {
      if (ws !== except) send(ws, msg);
    }
  }
}

function send(ws, msg) {
  try {
    ws.send(JSON.stringify(msg));
  } catch {
    // The socket is closing; its close handler updates the presence.
  }
}
