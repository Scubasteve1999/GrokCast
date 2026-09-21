/**
 * DayCast REFS agreement worker.
 * GET /v1/agreement?lat=&lon=&tz=&hours=
 * GET /v1/agreement?stub=1   documented sample, parallel:true, not a live extract
 * GET /health
 */

import { classify, stubPayload } from "./agreement.js";
import { domainFor } from "./grid.js";
import {
  findHrrrCycle,
  findRefsCycle,
  readHrrrSeries,
  readRefsSeries,
  cycleId,
} from "./extract.js";

const DEFAULT_HOURS = 12;
const MAX_HOURS = 18;

function json(body, status = 200, cacheSeconds = 0) {
  const headers = {
    "content-type": "application/json; charset=utf-8",
    "cache-control": cacheSeconds > 0 ? `public, max-age=${cacheSeconds}` : "no-store",
    "access-control-allow-origin": "*",
  };
  return new Response(JSON.stringify(body), { status, headers });
}

function hoursParam(url) {
  const raw = Number(url.searchParams.get("hours") ?? DEFAULT_HOURS);
  if (!Number.isFinite(raw)) return DEFAULT_HOURS;
  return Math.min(MAX_HOURS, Math.max(4, Math.round(raw)));
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, OPTIONS",
        },
      });
    }
    if (url.pathname === "/health") return json({ ok: true, product: "refs-agreement" });
    if (url.pathname !== "/v1/agreement") return json({ error: "not_found" }, 404);

    if (url.searchParams.get("stub") === "1") {
      return json(stubPayload(new Date()));
    }

    const lat = Number(url.searchParams.get("lat"));
    const lon = Number(url.searchParams.get("lon"));
    const timeZone = url.searchParams.get("tz") || "UTC";
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      return json({ error: "lat_lon_required" }, 400);
    }
    try {
      new Intl.DateTimeFormat("en-US", { timeZone }).format(new Date());
    } catch {
      return json({ error: "bad_timezone" }, 400);
    }

    const domain = domainFor(lat, lon);
    if (!domain) return json({ error: "outside_refs_domain" }, 404);

    const hours = hoursParam(url);
    const now = new Date();
    try {
      const refsCycle = await findRefsCycle(fetch, domain, now, hours);
      if (!refsCycle) return json({ error: "refs_unavailable", parallel: true }, 503);
      const refsHours = await readRefsSeries(fetch, refsCycle, domain, lat, lon, hours, now);
      if (!refsHours) return json({ error: "refs_unavailable", parallel: true }, 503);

      let hrrrHours = null;
      let hrrrCycle = null;
      try {
        hrrrCycle = await findHrrrCycle(fetch, domain, now);
        if (hrrrCycle) {
          hrrrHours = await readHrrrSeries(fetch, hrrrCycle, domain, lat, lon, hours, now);
        }
      } catch {
        hrrrHours = null;
        hrrrCycle = null;
      }

      const payload = classify(refsHours, hrrrHours, timeZone, {
        refsCycle: cycleId(refsCycle),
        hrrrCycle: hrrrCycle ? cycleId(hrrrCycle) : null,
        domain,
        asOf: now,
      });
      return json(payload, 200, 600);
    } catch {
      return json({ error: "refs_unavailable", parallel: true }, 503);
    }
  },
};
