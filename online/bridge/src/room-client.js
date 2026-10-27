// Connection of one player to their room. Keeps the room as the server
// last described it and the events of the other players, and reconnects on
// its own after a lost connection.
const MAX_EVENTS = 1000;
const RETRY_MIN_MS = 1000;
const RETRY_MAX_MS = 10000;

export class RoomClient {
  constructor({ server, groupKey, name, secret }, { WebSocketImpl = WebSocket, fetchImpl = fetch, log = () => {} } = {}) {
    Object.assign(this, { server, groupKey, name, secret, WebSocketImpl, fetchImpl, log });
    this.room = null;     // welcome + presence
    this.events = [];     // { n, from, data }, oldest first
    this.lastEvent = 0;
    this.outbox = [];     // events sent while disconnected
    this.ws = null;
    this.retryMs = RETRY_MIN_MS;
    this.closed = false;
  }

  get headers() {
    return { Authorization: `Bearer ${this.groupKey}` };
  }

  async createRoom(rules) {
    const res = await this.fetchImpl(`${this.server}/rooms`, {
      method: "POST",
      headers: { ...this.headers, "Content-Type": "application/json" },
      body: JSON.stringify({ name: this.name, secret: this.secret, rules }),
    });
    if (res.status !== 201) throw new Error(`Création du salon refusée (${res.status}).`);
    return (await res.json()).code;
  }

  connect(code) {
    this.code = code;
    const url = `${this.server.replace(/^http/, "ws")}/rooms/${code}/ws?name=${encodeURIComponent(this.name)}&secret=${this.secret}`;
    const ws = new this.WebSocketImpl(url, { headers: this.headers });
    this.ws = ws;
    ws.onopen = () => {
      this.retryMs = RETRY_MIN_MS;
      this.outbox.splice(0).forEach((data) => this.publish(data));
    };
    ws.onmessage = (e) => this.receive(JSON.parse(e.data));
    ws.onclose = (e) => {
      if (this.ws !== ws) return;
      this.ws = null;
      if (this.room) this.room.connected = false;
      // 4000: this player joined from elsewhere; 4001: removed from the room.
      if (this.closed || e.code === 4000 || e.code === 4001) return;
      this.log("connection_lost", this.retryMs);
      setTimeout(() => !this.closed && this.connect(code), this.retryMs);
      this.retryMs = Math.min(this.retryMs * 2, RETRY_MAX_MS);
    };
  }

  receive(msg) {
    switch (msg.type) {
      case "welcome": {
        const { type, ...welcome } = msg;
        this.room = { ...this.room, ...welcome, connected: true };
        break;
      }
      case "presence": {
        // goneFor counts on from here: the server only sends changes.
        const now = Date.now();
        const players = msg.players.map(({ goneFor, ...p }) => ({ ...p, goneAt: goneFor == null ? null : now - (goneFor * 1000) }));
        this.room = { ...this.room, players, allConnected: msg.allConnected };
        break;
      }
      case "start":
        this.room = { ...this.room, started: true, seed: msg.seed, rules: msg.rules };
        break;
      case "kicked":
        if (msg.id === this.room?.you) {
          this.room = { ...this.room, kicked: true };
        } else {
          // Shown to the game like an announcement of that player.
          this.pushEvent(msg.id, { kind: "news", what: "kicked", name: msg.name });
        }
        break;
      case "event":
        this.pushEvent(msg.from, msg.data);
        break;
    }
    this.log(msg.type, msg);
  }

  pushEvent(from, data) {
    this.events.push({ n: ++this.lastEvent, from, data });
    if (this.events.length > MAX_EVENTS) this.events.shift();
  }

  // Sent to the other players; kept for later while disconnected.
  publish(data) {
    if (this.ws?.readyState !== 1) return void this.outbox.push(data);
    this.ws.send(JSON.stringify({ type: "event", data }));
  }

  start() {
    this.ws?.send(JSON.stringify({ type: "start" }));
  }

  // Host only: removes a player gone for 5 minutes (the server checks).
  kick(id) {
    this.ws?.send(JSON.stringify({ type: "kick", id }));
  }

  // The room as the game sees it: how long each absent player has been gone.
  snapshot(now = Date.now()) {
    if (!this.room) return null;
    const players = this.room.players?.map(({ goneAt, ...p }) => ({ ...p, goneFor: goneAt == null ? null : Math.floor((now - goneAt) / 1000) }));
    return { ...this.room, players };
  }

  eventsAfter(n) {
    return this.events.filter((e) => e.n > n);
  }

  close() {
    this.closed = true;
    this.ws?.close(1000);
  }
}
