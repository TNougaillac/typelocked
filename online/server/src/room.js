// One room of friends (Durable Object). It keeps the rules, the seed and the
// players, knows who is connected (and since when a player is gone, once the
// game started) and relays each player's events to the others. The host can
// remove a player gone for KICK_AFTER_MS. WebSockets use the Hibernation
// API: an idle room costs nothing.
import { DurableObject } from "cloudflare:workers";
import { KICK_AFTER_MS, MAX_EVENT_BYTES, MAX_PLAYERS, isSecret, json, parseName, playerId, randomSeed } from "./protocol.js";

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
    const players = await this.presence();
    const statuses = await this.ctx.storage.get(players.map((p) => `status:${p.id}`));
    for (const p of players) p.status = statuses.get(`status:${p.id}`) || null;
    return json({ code, rules, started, players });
  }

  async join(request, code, params) {
    if (request.headers.get("Upgrade") !== "websocket") return json({ error: "websocket_expected" }, 426);
    const room = await this.ctx.storage.get("room");
    if (!room) return json({ error: "not_found" }, 404);
    const name = parseName(params.get("name"));
    const secret = params.get("secret");
    if (!name || !isSecret(secret)) return json({ error: "bad_request" }, 400);
    const id = await playerId(code, secret);
    const kicked = (await this.ctx.storage.get("kicked")) || [];
    if (kicked.includes(id)) return this.refuseKicked(id);
    const players = await this.ctx.storage.get("players");
    if (!players[id]) {
      if (room.started) return json({ error: "started" }, 409);
      if (Object.keys(players).length >= MAX_PLAYERS) return json({ error: "full" }, 409);
    }
    players[id] = { name };
    await this.ctx.storage.put("players", players);
    await this.ctx.storage.delete(`gone:${id}`);
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
      // A player's last progress stays with the room (scores for the launcher).
      if (msg.data.kind === "status") await this.ctx.storage.put(`status:${id}`, msg.data);
      return this.broadcast({ type: "event", from: id, data: msg.data }, ws);
    }
    if (msg?.type === "start") return this.start(ws, id);
    if (msg?.type === "kick") return this.kick(ws, id, msg.id);
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

  // The host removes a player gone for KICK_AFTER_MS: the others go on, the
  // removed player finishes their game solo.
  async kick(ws, id, target) {
    const room = await this.ctx.storage.get("room");
    if (id !== room.hostId) return send(ws, { type: "error", error: "not_host" });
    const players = await this.ctx.storage.get("players");
    const gone = await this.ctx.storage.get(`gone:${target}`);
    if (!players[target] || target === id) return send(ws, { type: "error", error: "unknown_player" });
    if (!gone || Date.now() - gone < KICK_AFTER_MS) return send(ws, { type: "error", error: "too_soon" });
    const { name } = players[target];
    delete players[target];
    const kicked = (await this.ctx.storage.get("kicked")) || [];
    await this.ctx.storage.put({ players, kicked: [...kicked, target] });
    await this.ctx.storage.delete(`gone:${target}`);
    this.broadcast({ type: "kicked", id: target, name });
    await this.broadcastPresence();
  }

  // A removed player is told so, then closed (4001: do not come back).
  refuseKicked(id) {
    const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    send(server, { type: "kicked", id });
    server.close(4001, "kicked");
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketClose(ws, code) {
    try {
      ws.close(code === 1005 ? 1000 : code, "closed");
    } catch {
      // Already closed by the runtime.
    }
    await this.markGone(ws);
    await this.broadcastPresence(ws);
  }

  // Once the game started, remembers since when a player is gone.
  async markGone(ws) {
    const { id } = ws.deserializeAttachment() || {};
    const room = await this.ctx.storage.get("room");
    if (!id || !room?.started) return;
    if (this.ctx.getWebSockets(id).some((other) => other !== ws && other.readyState === WebSocket.OPEN)) return;
    if (!(await this.ctx.storage.get(`gone:${id}`))) await this.ctx.storage.put(`gone:${id}`, Date.now());
  }

  async webSocketError(ws) {
    await this.markGone(ws);
    await this.broadcastPresence(ws);
  }

  // Players in join order, with who is connected (gone: a socket being closed).
  async presence(gone = null) {
    const room = await this.ctx.storage.get("room");
    const players = (await this.ctx.storage.get("players")) || {};
    const goneSince = await this.ctx.storage.get(Object.keys(players).map((id) => `gone:${id}`));
    return Object.entries(players).map(([id, { name }]) => {
      const connected = this.ctx.getWebSockets(id).some((ws) => ws !== gone && ws.readyState === WebSocket.OPEN);
      // Seconds since the player left, once the game started (null: here, or not started).
      const since = goneSince.get(`gone:${id}`);
      return { id, name, host: id === room.hostId, connected, goneFor: !connected && since ? Math.floor((Date.now() - since) / 1000) : null };
    });
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
