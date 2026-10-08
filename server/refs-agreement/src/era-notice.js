/**
 * Slip-date payload for the DayCast RRFS/REFS banner.
 * Missing or invalid KV falls back to the same dates the app ships as constants.
 */

// SCN 26-48 Updated (AAE, Oct 2 2026) moved the cutover from Oct 14 to Nov 3.
// Keep in lockstep with `ForecastEraNotice.fallback` in the app.
export const DEFAULT_ERA_NOTICE = {
  id: "rrfs-2026-11-03",
  cutoverUTC: "2026-11-03T12:00:00Z",
  windowStartUTC: "2026-10-07T12:00:00Z",
  windowEndUTC: "2026-11-17T12:00:00Z",
  status: "slipped",
  updatedAt: "2026-10-08T00:00:00Z",
};

const MIN_MS = Date.parse("2026-10-01T00:00:00Z");
const MAX_MS = Date.parse("2026-12-31T23:59:59Z");
const STATUSES = new Set(["scheduled", "slipped", "done"]);
const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;

function parseISO(value) {
  if (typeof value !== "string" || !ISO_INSTANT.test(value)) return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
}

function inBounds(ms) {
  return ms >= MIN_MS && ms <= MAX_MS;
}

export function sanitizeEraNotice(raw) {
  let obj = raw;
  if (typeof raw === "string") {
    try {
      obj = JSON.parse(raw);
    } catch {
      return { ...DEFAULT_ERA_NOTICE };
    }
  }
  if (obj == null || typeof obj !== "object") return { ...DEFAULT_ERA_NOTICE };

  const id = typeof obj.id === "string" ? obj.id.trim() : "";
  if (!id || !STATUSES.has(obj.status)) return { ...DEFAULT_ERA_NOTICE };

  const start = parseISO(obj.windowStartUTC);
  const cutover = parseISO(obj.cutoverUTC);
  const end = parseISO(obj.windowEndUTC);
  const updated = parseISO(obj.updatedAt);
  if (start == null || cutover == null || end == null || updated == null) {
    return { ...DEFAULT_ERA_NOTICE };
  }
  if (!inBounds(start) || !inBounds(cutover) || !inBounds(end)) {
    return { ...DEFAULT_ERA_NOTICE };
  }
  if (!(start < cutover && cutover < end)) return { ...DEFAULT_ERA_NOTICE };

  return {
    id,
    cutoverUTC: obj.cutoverUTC,
    windowStartUTC: obj.windowStartUTC,
    windowEndUTC: obj.windowEndUTC,
    status: obj.status,
    updatedAt: obj.updatedAt,
  };
}

export async function readEraNotice(env) {
  try {
    const raw = await env?.ERA_NOTICE?.get("current");
    if (raw == null || raw === "") return { ...DEFAULT_ERA_NOTICE };
    return sanitizeEraNotice(raw);
  } catch {
    return { ...DEFAULT_ERA_NOTICE };
  }
}
