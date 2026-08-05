/**
 * DayCast Pro proxy — forwards xAI requests for verified subscribers.
 *
 * The xAI key lives here and never ships in the app. Access requires a StoreKit 2
 * signed transaction that this worker verifies against Apple's pinned root, so a
 * leaked `PROXY_SECRET` alone buys nothing.
 *
 * Bindings (see wrangler.toml):
 *   USAGE                 KV namespace for daily counters
 * Secrets (`wrangler secret put`):
 *   XAI_API_KEY           server-side xAI key
 *   PROXY_SECRET          shared string the app sends; public by necessity
 * Vars:
 *   BUNDLE_ID, PRO_PRODUCT_IDS, ALLOWED_ENVIRONMENTS,
 *   DAILY_CHAT_LIMIT, DAILY_IMAGE_LIMIT, GLOBAL_DAILY_LIMIT,
 *   ALERT_THRESHOLD, DISABLED, OWM_DAILY_LIMIT, OWM_CACHE_TTL, OWM_DISABLED
 * Secrets, continued:
 *   OWM_API_KEY           OpenWeatherMap key; One Call 4.0 is billed per request
 */

import { TransactionError, verifyTransaction } from "./appleTransaction.js";
import { handleOpenWeather } from "./openweather.js";
import {
  GLOBAL_SUBJECT,
  consume,
  lastReportDay,
  refund,
  reportKey,
  resetsAt,
  snapshot,
} from "./usage.js";

const XAI_BASE = "https://api.x.ai/v1";
const TRANSACTION_HEADER = "X-DayCast-Transaction";

/** Only these paths reach xAI. Without this, a leaked secret would expose the whole API. */
const ROUTES = {
  "/v1/chat/completions": { bucket: "chat", limitVar: "DAILY_CHAT_LIMIT", fallback: 150 },
  "/v1/images/generations": { bucket: "image", limitVar: "DAILY_IMAGE_LIMIT", fallback: 10 },
};

function jsonResponse(status, body, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

function errorResponse(status, message, type, extraHeaders = {}) {
  return jsonResponse(status, { error: { message, type } }, extraHeaders);
}

function numberVar(env, name, fallback) {
  const value = Number.parseInt(env[name] ?? "", 10);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function listVar(env, name, fallback) {
  const raw = (env[name] ?? "").trim();
  if (!raw) return fallback;
  return raw
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

/** Length-independent comparison, so the secret can't be recovered by timing. */
function secretsMatch(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return diff === 0;
}

function authorized(request, env) {
  const authorization = request.headers.get("Authorization") ?? "";
  const presented = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  return Boolean(env.PROXY_SECRET) && secretsMatch(presented, env.PROXY_SECRET);
}

function usageHeaders(result) {
  return {
    "X-DayCast-Limit": String(result.limit),
    "X-DayCast-Remaining": String(result.remaining),
    "X-DayCast-Reset": new Date(result.resetsAt).toISOString(),
  };
}

/**
 * `options` exists so tests can pin a throwaway certificate root, stub the
 * upstream, and drive the clock. Production always takes the defaults.
 */
async function handle(request, env, options = {}) {
  const { rootCertificate, fetchImpl = fetch, now = Date.now() } = options;
  const url = new URL(request.url);

  if (url.pathname === "/v1/health") {
    return jsonResponse(200, { ok: true, disabled: env.DISABLED === "1" });
  }

  if (url.pathname === "/v1/alert") {
    // Deliberately unauthenticated and deliberately contentless: a single boolean
    // saying whether today crossed the threshold. That lets an external checker
    // watch it without holding any credential, and leaks no usage figures.
    // Numbers live behind /v1/status.
    if (!env.USAGE) return jsonResponse(200, { over: false, unavailable: true });
    const usage = await snapshot(env.USAGE, {
      now,
      alertThreshold: numberVar(env, "ALERT_THRESHOLD", 500),
    });
    // `lastRollup` lets the checker verify the cron trigger is still alive. A
    // date is not usage data, so it stays on the unauthenticated endpoint.
    return jsonResponse(200, {
      over: usage.over,
      day: usage.day,
      lastRollup: await lastReportDay(env.USAGE),
    });
  }


  if (url.pathname.startsWith("/v1/owm/")) {
    // No StoreKit check here on purpose: weather is free in the app, so requiring
    // an entitlement would break it for every non-subscriber. See openweather.js.
    if (!authorized(request, env)) {
      return errorResponse(401, "Unauthorized", "authentication_error");
    }
    if (env.OWM_DISABLED === "1") {
      return errorResponse(503, "Weather data temporarily unavailable.", "service_disabled");
    }
    if (request.method !== "GET") {
      return errorResponse(405, "Method not allowed", "invalid_request_error");
    }

    const cache = options.cache ?? (typeof caches !== "undefined" ? caches.default : null);
    const result = await handleOpenWeather(url, env, {
      fetchImpl,
      cacheMatch: (key) => (cache ? cache.match(key) : Promise.resolve(undefined)),
      cachePut: (key, response) => (cache ? cache.put(key, response) : Promise.resolve()),
      consumeQuota: async () => {
        if (!env.USAGE) return true;
        const quota = await consume(env.USAGE, {
          bucket: "owm",
          subject: GLOBAL_SUBJECT,
          limit: numberVar(env, "OWM_DAILY_LIMIT", 5000),
          now,
        });
        return quota.ok;
      },
    });

    const headers = { "X-DayCast-Cache": result.cache ?? "MISS" };
    if (result.response) {
      const passthrough = new Headers(result.response.headers);
      passthrough.set("X-DayCast-Cache", result.cache ?? "MISS");
      return new Response(result.response.body, {
        status: result.response.status,
        headers: passthrough,
      });
    }
    return jsonResponse(result.status, result.body, headers);
  }

  if (url.pathname === "/v1/status") {
    // Same bearer as the proxy itself. That string ships in the app binary and is
    // public by necessity, so gating here adds no new secret — it just keeps
    // usage figures off an open endpoint.
    if (!authorized(request, env)) {
      return errorResponse(401, "Unauthorized", "authentication_error");
    }
    if (!env.USAGE) {
      return errorResponse(503, "Usage store is not bound.", "service_disabled");
    }
    return jsonResponse(200, {
      ok: true,
      disabled: env.DISABLED === "1",
      usage: await snapshot(env.USAGE, {
        now,
        alertThreshold: numberVar(env, "ALERT_THRESHOLD", 500),
      }),
    });
  }

  const route = ROUTES[url.pathname];
  if (!route) return errorResponse(404, "Not found", "invalid_request_error");
  if (request.method !== "POST") {
    return errorResponse(405, "Method not allowed", "invalid_request_error");
  }

  // Kill switch — the one lever that works without an App Store release.
  if (env.DISABLED === "1") {
    return errorResponse(503, "AI is temporarily unavailable.", "service_disabled");
  }

  if (!env.XAI_API_KEY) {
    return errorResponse(503, "Proxy is not configured.", "service_disabled");
  }
  if (!env.USAGE) {
    return errorResponse(503, "Usage store is not bound.", "service_disabled");
  }

  if (!authorized(request, env)) {
    return errorResponse(401, "Unauthorized", "authentication_error");
  }

  let entitlement;
  try {
    entitlement = await verifyTransaction(request.headers.get(TRANSACTION_HEADER), {
      bundleId: env.BUNDLE_ID ?? "com.scubasteve1999.GrokCast",
      productIds: listVar(env, "PRO_PRODUCT_IDS", [
        "com.scubasteve1999.GrokCast.pro.monthly",
        "com.scubasteve1999.GrokCast.pro.yearly",
      ]),
      environments: listVar(env, "ALLOWED_ENVIRONMENTS", ["Production", "Sandbox"]),
      rootCertificate,
      now,
    });
  } catch (error) {
    if (error instanceof TransactionError) {
      // Surfaced in `wrangler tail`. A rejection returns before metering, so
      // without this a refused call is indistinguishable from a served one.
      console.log(`entitlement rejected: ${error.message}`);
      return errorResponse(403, `DayCast Pro required: ${error.message}`, "entitlement_error");
    }
    throw error;
  }

  const subject = entitlement.originalTransactionId;
  const limit = numberVar(env, route.limitVar, route.fallback);

  const perUser = await consume(env.USAGE, { bucket: route.bucket, subject, limit, now });
  if (!perUser.ok) {
    return errorResponse(
      429,
      "AI limit reached for today.",
      "daily_limit_exceeded",
      usageHeaders(perUser)
    );
  }

  const global = await consume(env.USAGE, {
    bucket: "global",
    subject: GLOBAL_SUBJECT,
    limit: numberVar(env, "GLOBAL_DAILY_LIMIT", 5000),
    now,
  });
  if (!global.ok) {
    await refund(env.USAGE, { bucket: route.bucket, subject, now });
    return errorResponse(503, "AI is temporarily unavailable.", "service_capacity", {
      "X-DayCast-Reset": new Date(resetsAt(now)).toISOString(),
    });
  }

  const releaseCredits = async () => {
    await refund(env.USAGE, { bucket: route.bucket, subject, now });
    await refund(env.USAGE, { bucket: "global", subject: GLOBAL_SUBJECT, now });
  };

  // Rebuild headers rather than forwarding the client's — the inbound set carries
  // Host, the proxy secret, and the transaction, none of which belong upstream.
  const upstreamHeaders = new Headers({
    Authorization: `Bearer ${env.XAI_API_KEY}`,
    "Content-Type": request.headers.get("Content-Type") ?? "application/json",
  });
  const accept = request.headers.get("Accept");
  if (accept) upstreamHeaders.set("Accept", accept);

  let upstream;
  try {
    upstream = await fetchImpl(`${XAI_BASE}${url.pathname.slice("/v1".length)}${url.search}`, {
      method: "POST",
      headers: upstreamHeaders,
      body: request.body,
    });
  } catch (error) {
    await releaseCredits();
    return errorResponse(502, "AI is temporarily unavailable.", "upstream_error");
  }

  // Don't bill a request xAI refused. Body streams untouched on success, so this
  // is the last point where the outcome is still knowable.
  if (!upstream.ok) await releaseCredits();

  const responseHeaders = new Headers(upstream.headers);
  responseHeaders.delete("Set-Cookie");
  for (const [key, value] of Object.entries(usageHeaders(perUser))) {
    responseHeaders.set(key, value);
  }

  return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
}

/**
 * Daily rollup, run by the cron trigger just before UTC midnight so it sees the
 * day's finished totals rather than a partial one.
 *
 * There is no notification channel here on purpose: sending email needs a domain
 * onboarded to Cloudflare, and this account has none. The rollup is written to
 * KV and exposed on `/v1/status`, which a scheduled check reads. `console.log`
 * puts it in `wrangler tail` too.
 */
async function runDailyRollup(env, now = Date.now()) {
  if (!env.USAGE) return null;

  const usage = await snapshot(env.USAGE, {
    now,
    alertThreshold: numberVar(env, "ALERT_THRESHOLD", 500),
  });

  // Kept for 30 days so a week of history survives the counters' own 48h TTL.
  await env.USAGE.put(reportKey(usage.day), JSON.stringify(usage), {
    expirationTtl: 30 * 24 * 60 * 60,
  });

  console.log(
    `daily rollup ${usage.day}: global=${usage.global} chat=${usage.chat} ` +
      `image=${usage.image} subscribers=${usage.subscribers} over=${usage.over}`
  );

  return usage;
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runDailyRollup(env));
  },

  async fetch(request, env) {
    try {
      const response = await handle(request, env);
      // `wrangler tail` reports "Ok" for anything that didn't throw, so a 401 and
      // a served request look identical without this.
      console.log(`${request.method} ${new URL(request.url).pathname} -> ${response.status}`);
      return response;
    } catch (error) {
      console.error("proxy error", error);
      return errorResponse(500, "AI is temporarily unavailable.", "internal_error");
    }
  },
};

export { handle, runDailyRollup };
