import assert from "node:assert/strict";
import test from "node:test";

import { resolveTarget } from "../src/openweather.js";
import { handle } from "../src/worker.js";
import { memoryKV, proxyRequest, testEnv } from "./helpers.js";

const NOON = Date.parse("2026-08-02T12:00:00Z");
const BASE = "https://proxy.example.com";

function owmEnv(overrides = {}) {
  return testEnv({ OWM_API_KEY: "owm-test-key", USAGE: memoryKV(), ...overrides });
}

/** In-memory stand-in for the Cloudflare Cache API. */
function memoryCache() {
  const store = new Map();
  return {
    store,
    async match(key) {
      const hit = store.get(key.url);
      return hit ? hit.clone() : undefined;
    },
    async put(key, response) {
      store.set(key.url, response);
    },
  };
}

function stubUpstream({ status = 200, body = '{"temp":72}' } = {}) {
  const calls = [];
  return {
    calls,
    fetchImpl: async (url) => {
      calls.push(url);
      return new Response(body, { status, headers: { "Content-Type": "application/json" } });
    },
  };
}

async function call(path, { env = owmEnv(), upstream = stubUpstream(), cache = memoryCache() } = {}) {
  const request = proxyRequest({ path, method: "GET" });
  const response = await handle(request, env, {
    now: NOON,
    fetchImpl: upstream.fetchImpl,
    cache,
  });
  return { response, env, upstream, cache };
}

test("resolveTarget rejects paths outside the allowlist", () => {
  assert.equal(resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/air_pollution?lat=1&lon=2`)), null);
  assert.equal(resolveTarget(new URL(`${BASE}/v1/owm/../../etc/passwd?lat=1&lon=2`)), null);
});

test("resolveTarget requires coordinates", () => {
  assert.equal(resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/weather?units=imperial`)), null);
});

test("resolveTarget never forwards a client-supplied appid", () => {
  const target = resolveTarget(
    new URL(`${BASE}/v1/owm/data/2.5/weather?lat=35&lon=-90&appid=attacker-key`)
  );
  assert.equal(target.upstream.searchParams.get("appid"), null);
});

test("the cache key rounds coordinates so a neighbourhood shares one upstream call", () => {
  const a = resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/weather?lat=34.9612&lon=-89.8299`));
  const b = resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/weather?lat=34.9634&lon=-89.8271`));

  assert.equal(a.cacheKey.url, b.cacheKey.url, "nearby callers must share a cache entry");
  // Upstream still receives full precision.
  assert.equal(a.upstream.searchParams.get("lat"), "34.9612");
});

test("parameter order does not fragment the cache", () => {
  const a = resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/weather?lat=35&lon=-90&units=imperial`));
  const b = resolveTarget(new URL(`${BASE}/v1/owm/data/2.5/weather?units=imperial&lon=-90&lat=35`));
  assert.equal(a.cacheKey.url, b.cacheKey.url);
});

test("a request is forwarded with the server key and returns the payload", async () => {
  const upstream = stubUpstream();
  const { response } = await call("/v1/owm/data/4.0/onecall/current?lat=35&lon=-90", { upstream });

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("X-SpotterCast-Cache"), "MISS");
  assert.equal(upstream.calls.length, 1);
  assert.match(upstream.calls[0], /appid=owm-test-key/);
  assert.match(upstream.calls[0], /^https:\/\/api\.openweathermap\.org\/data\/4\.0\/onecall\/current/);
});

test("a second identical request is served from cache and not billed", async () => {
  const env = owmEnv();
  const upstream = stubUpstream();
  const cache = memoryCache();

  await call("/v1/owm/data/2.5/weather?lat=35.00&lon=-90.00", { env, upstream, cache });
  const second = await call("/v1/owm/data/2.5/weather?lat=35.001&lon=-90.004", {
    env,
    upstream,
    cache,
  });

  assert.equal(second.response.headers.get("X-SpotterCast-Cache"), "HIT");
  assert.equal(upstream.calls.length, 1, "the cached request must not reach OpenWeatherMap");
  assert.equal(
    env.USAGE.store.get("usage:v1:owm:__global__:2026-08-02"),
    "1",
    "a cache hit must not consume quota"
  );
});

test("weather does not require a subscription", async () => {
  // Deliberate: the app's weather is free, so an entitlement check here would
  // break it for everyone who has not subscribed.
  const upstream = stubUpstream();
  const { response } = await call("/v1/owm/data/2.5/weather?lat=35&lon=-90", { upstream });
  assert.equal(response.status, 200);
});

test("the shared secret is still required", async () => {
  const response = await handle(
    proxyRequest({ path: "/v1/owm/data/2.5/weather?lat=35&lon=-90", method: "GET", secret: "no" }),
    owmEnv(),
    { now: NOON, cache: memoryCache() }
  );
  assert.equal(response.status, 401);
});

test("an unlisted upstream path never reaches OpenWeatherMap", async () => {
  const upstream = stubUpstream();
  const { response } = await call("/v1/owm/data/2.5/air_pollution?lat=35&lon=-90", { upstream });
  assert.equal(response.status, 404);
  assert.equal(upstream.calls.length, 0);
});

test("the daily cap stops upstream calls", async () => {
  const env = owmEnv({ OWM_DAILY_LIMIT: "1" });
  const upstream = stubUpstream();

  await call("/v1/owm/data/2.5/weather?lat=1&lon=1", { env, upstream, cache: memoryCache() });
  const second = await call("/v1/owm/data/2.5/weather?lat=2&lon=2", {
    env,
    upstream,
    cache: memoryCache(),
  });

  assert.equal(second.response.status, 503);
  assert.equal(upstream.calls.length, 1);
});

test("the weather kill switch is independent of the AI one", async () => {
  const aiOff = await call("/v1/owm/data/2.5/weather?lat=35&lon=-90", {
    env: owmEnv({ DISABLED: "1" }),
  });
  assert.equal(aiOff.response.status, 200, "disabling AI must not disable weather");

  const weatherOff = await call("/v1/owm/data/2.5/weather?lat=35&lon=-90", {
    env: owmEnv({ OWM_DISABLED: "1" }),
  });
  assert.equal(weatherOff.response.status, 503);
});

test("an upstream failure is passed through but never cached", async () => {
  const cache = memoryCache();
  const upstream = stubUpstream({ status: 401, body: '{"cod":401}' });

  const { response } = await call("/v1/owm/data/2.5/weather?lat=35&lon=-90", { upstream, cache });

  assert.equal(response.status, 401);
  // A cached 401 would outlive a key rotation and keep failing after the fix.
  assert.equal(cache.store.size, 0);
});

test("an unlisted path 404s even when the key is unset", async () => {
  // Otherwise a missing key masks a routing mistake as a configuration one.
  const env = owmEnv({ OWM_API_KEY: "" });
  const { response } = await call("/v1/owm/data/2.5/air_pollution?lat=35&lon=-90", { env });
  assert.equal(response.status, 404);
});

test("an allowlisted path reports a missing key honestly", async () => {
  const env = owmEnv({ OWM_API_KEY: "" });
  const { response } = await call("/v1/owm/data/2.5/weather?lat=35&lon=-90", { env });
  assert.equal(response.status, 503);
});
