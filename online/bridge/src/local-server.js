// What the game sees of the bridge: a small HTTP service on this PC only.
//   GET  /state              -> { room } (null outside a room)
//   GET  /events?after=N     -> { events: [{ n, from, data }], last }
//   POST /event   { data }   -> 204, sent to the other players
import { createServer } from "node:http";

const MAX_BODY = 8192;

export function startLocalServer(client, port, host = "127.0.0.1") {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://local");
    try {
      if (req.method === "GET" && url.pathname === "/state") return reply(res, 200, { room: client.room });
      if (req.method === "GET" && url.pathname === "/events") {
        const after = Number(url.searchParams.get("after")) || 0;
        return reply(res, 200, { events: client.eventsAfter(after), last: client.lastEvent });
      }
      if (req.method === "POST" && url.pathname === "/event") {
        const body = JSON.parse(await readBody(req));
        if (!body || typeof body.data !== "object" || body.data === null) return reply(res, 400, { error: "bad_request" });
        client.publish(body.data);
        res.writeHead(204).end();
        return;
      }
      reply(res, 404, { error: "not_found" });
    } catch {
      reply(res, 400, { error: "bad_request" });
    }
  });
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => resolve(server));
  });
}

function reply(res, status, data) {
  res.writeHead(status, { "Content-Type": "application/json" }).end(JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > MAX_BODY) reject(new Error("too_large"));
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}
