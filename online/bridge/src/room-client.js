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
      if (this.closed || e.code === 4000) return; // 4000: this player joined from elsewhere
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
      case "presence":
        this.room = { ...this.room, players: msg.players, allConnected: msg.allConnected };
        break;
      case "start":
        this.room = { ...this.room, started: true, seed: msg.seed, rules: msg.rules };
        break;
      case "event":
        this.events.push({ n: ++this.lastEvent, from: msg.from, data: msg.data });
        if (this.events.length > MAX_EVENTS) this.events.shift();
        break;
    }
    this.log(msg.type, msg);
  }

  // Sent to the other players; kept for later while disconnected.
  publish(data) {
    if (this.ws?.readyState !== 1) return void this.outbox.push(data);
    this.ws.send(JSON.stringify({ type: "event", data }));
  }

  start() {
    this.ws?.send(JSON.stringify({ type: "start" }));
  }

  eventsAfter(n) {
    return this.events.filter((e) => e.n > n);
  }

  close() {
    this.closed = true;
    this.ws?.close(1000);
  }
}
