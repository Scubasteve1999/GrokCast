/**
 * GrokCast Pro proxy — forwards xAI-compatible requests for subscribed users.
 * Deploy to Cloudflare Workers, Vercel Edge, or any Node 18+ host.
 *
 * Environment:
 *   XAI_API_KEY     — your server-side xAI key (never ship to the app)
 *   PROXY_SECRET    — optional shared secret (default: grokcast-pro)
 *   DAILY_REQ_LIMIT — max requests per subscription ID per day (default: 200)
 */

const PROXY_SECRET = globalThis.PROXY_SECRET || "grokcast-pro";
const XAI_BASE = "https://api.x.ai/v1";
const DAILY_LIMIT = Number(globalThis.DAILY_REQ_LIMIT || 200);

/** @type {Map<string, { count: number, day: string }>} */
const usage = new Map();

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function checkRateLimit(subscriptionId) {
  if (!subscriptionId) return { ok: false, reason: "missing subscription id" };
  const day = todayKey();
  const entry = usage.get(subscriptionId) || { count: 0, day };
  if (entry.day !== day) {
    entry.count = 0;
    entry.day = day;
  }
  if (entry.count >= DAILY_LIMIT) {
    return { ok: false, reason: "daily limit exceeded" };
  }
  entry.count += 1;
  usage.set(subscriptionId, entry);
  return { ok: true };
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, X-GrokCast-Subscription-Id",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
}

async function handleRequest(request) {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  const auth = request.headers.get("Authorization") || "";
  if (auth !== `Bearer ${PROXY_SECRET}`) {
    return new Response(JSON.stringify({ error: { message: "Unauthorized" } }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  const subscriptionId = request.headers.get("X-GrokCast-Subscription-Id");
  const limit = checkRateLimit(subscriptionId);
  if (!limit.ok) {
    return new Response(JSON.stringify({ error: { message: limit.reason } }), {
      status: 429,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  const xaiKey = globalThis.XAI_API_KEY;
  if (!xaiKey) {
    return new Response(JSON.stringify({ error: { message: "Proxy not configured" } }), {
      status: 503,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/v1/, "");
  const target = `${XAI_BASE}${path}${url.search}`;

  const headers = new Headers(request.headers);
  headers.set("Authorization", `Bearer ${xaiKey}`);
  headers.delete("X-GrokCast-Subscription-Id");

  const init = {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
  };

  const upstream = await fetch(target, init);
  const responseHeaders = new Headers(upstream.headers);
  Object.entries(corsHeaders()).forEach(([k, v]) => responseHeaders.set(k, v));

  return new Response(upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}

// Cloudflare Workers export
export default { fetch: handleRequest };

// Node / local dev
if (typeof module !== "undefined") {
  const http = require("http");
  const port = process.env.PORT || 8787;
  http
    .createServer((req, res) => {
      const url = `http://localhost${req.url}`;
      const chunks = [];
      req.on("data", (c) => chunks.push(c));
      req.on("end", async () => {
        const body = chunks.length ? Buffer.concat(chunks) : undefined;
        const request = new Request(url, {
          method: req.method,
          headers: req.headers,
          body: req.method === "GET" ? undefined : body,
        });
        const response = await handleRequest(request);
        res.writeHead(response.status, Object.fromEntries(response.headers));
        const text = await response.text();
        res.end(text);
      });
    })
    .listen(port, () => console.log(`Grok proxy listening on :${port}`));
}
