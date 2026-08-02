/**
 * OpenWeatherMap data-API proxy.
 *
 * One Call 4.0 is billed per request, so an `appid` compiled into every copy of
 * the app is the same shape of problem the xAI key was: unrevocable without an
 * App Store release, and spendable by anyone who extracts it.
 *
 * Unlike the Grok routes this does **not** require a StoreKit entitlement —
 * weather is free in the app, so demanding a subscription would break it for
 * everyone. The shared secret is the only gate, and it ships in the binary.
 * That means this does not make the key unreachable; it makes it *controllable*:
 * rotatable server-side, capped, cacheable, and killable without a release.
 *
 * Caching is the part that actually reduces the bill. Weather for a given place
 * does not change second to second, so identical requests inside the TTL are
 * served from Cloudflare's edge and never billed.
 */

const OWM_HOST = "https://api.openweathermap.org";

/** Only these upstream paths are reachable. Everything else 404s. */
const ALLOWED_PATHS = new Set([
  "/data/4.0/onecall/current",
  "/data/4.0/onecall/timeline/1h",
  "/data/4.0/onecall/timeline/15min",
  "/data/2.5/weather",
  "/data/2.5/forecast",
]);

/** Query parameters forwarded upstream. `appid` is deliberately not among them. */
const ALLOWED_PARAMS = ["lat", "lon", "units", "lang", "cnt", "exclude"];

const DEFAULT_TTL_SECONDS = 300;

/**
 * Rounds coordinates so nearby callers share a cache entry.
 *
 * Two decimals is a little over 1 km — far finer than weather varies, and it
 * turns "every user in a city" into one upstream call instead of hundreds.
 */
function roundCoordinate(value) {
  const number = Number.parseFloat(value);
  return Number.isFinite(number) ? number.toFixed(2) : null;
}

/**
 * Builds the upstream URL and a normalised cache key from an inbound request.
 * Returns null when the path is not allowlisted.
 */
export function resolveTarget(url) {
  const path = url.pathname.slice("/v1/owm".length);
  if (!ALLOWED_PATHS.has(path)) return null;

  const upstream = new URL(OWM_HOST + path);
  const cacheURL = new URL(`https://owm-cache.invalid${path}`);

  for (const name of ALLOWED_PARAMS) {
    const value = url.searchParams.get(name);
    if (value == null || value === "") continue;

    upstream.searchParams.set(name, value);

    // Coordinates are rounded for the cache key only — upstream still gets the
    // precise value, so responses stay accurate.
    if (name === "lat" || name === "lon") {
      const rounded = roundCoordinate(value);
      if (rounded == null) return null;
      cacheURL.searchParams.set(name, rounded);
    } else {
      cacheURL.searchParams.set(name, value);
    }
  }

  if (!upstream.searchParams.has("lat") || !upstream.searchParams.has("lon")) return null;

  // Sorted so parameter order cannot fragment the cache.
  cacheURL.searchParams.sort();
  return { upstream, cacheKey: new Request(cacheURL.toString(), { method: "GET" }) };
}

/**
 * @param {object} deps
 * @param {(request: Request) => Promise<Response|undefined>} deps.cacheMatch
 * @param {(request: Request, response: Response) => Promise<void>} deps.cachePut
 * @param {typeof fetch} deps.fetchImpl
 * @param {() => Promise<boolean>} deps.consumeQuota  false when the daily cap is hit
 */
export async function handleOpenWeather(url, env, deps) {
  const { cacheMatch, cachePut, fetchImpl, consumeQuota } = deps;

  const target = resolveTarget(url);
  if (!target) return { status: 404, body: { error: { message: "Not found" } } };

  // Checked after the allowlist so an unlisted path always reads as 404, whether
  // or not the key happens to be configured.
  if (!env.OWM_API_KEY) {
    return { status: 503, body: { error: { message: "Weather proxy is not configured." } } };
  }

  const cached = await cacheMatch(target.cacheKey);
  if (cached) return { response: cached, cache: "HIT" };

  // Only cache misses reach OpenWeatherMap, so only misses are billed — and only
  // misses count against the cap.
  if (!(await consumeQuota())) {
    return {
      status: 503,
      body: { error: { message: "Weather data temporarily unavailable." } },
      cache: "MISS",
    };
  }

  const upstream = new URL(target.upstream);
  upstream.searchParams.set("appid", env.OWM_API_KEY);

  let response;
  try {
    response = await fetchImpl(upstream.toString(), { method: "GET" });
  } catch {
    return {
      status: 502,
      body: { error: { message: "Weather data temporarily unavailable." } },
      cache: "MISS",
    };
  }

  if (!response.ok) {
    // Never cache a failure — a cached 401 would outlive a key rotation.
    return { response, cache: "MISS", cacheable: false };
  }

  const ttl = Number.parseInt(env.OWM_CACHE_TTL ?? "", 10);
  const seconds = Number.isFinite(ttl) && ttl > 0 ? ttl : DEFAULT_TTL_SECONDS;

  const body = await response.arrayBuffer();
  const cacheable = new Response(body, {
    status: response.status,
    headers: {
      "Content-Type": response.headers.get("Content-Type") ?? "application/json",
      "Cache-Control": `public, max-age=${seconds}`,
    },
  });

  await cachePut(target.cacheKey, cacheable.clone());
  return { response: cacheable, cache: "MISS" };
}
