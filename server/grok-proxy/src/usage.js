/**
 * Daily request counters in Workers KV.
 *
 * Chat and image generation get separate budgets — image calls cost far more
 * per request and must not be able to drain the chat allowance.
 *
 * KV is eventually consistent, so two concurrent requests can read the same
 * count and both write count+1, undercounting by one. That is acceptable for a
 * per-user fairness cap; the global ceiling is the control that actually bounds
 * spend. Move to a Durable Object if per-user accuracy ever has to be exact.
 */

const KEY_PREFIX = "usage:v1";
const TTL_SECONDS = 48 * 60 * 60;

export function dayKey(now) {
  return new Date(now).toISOString().slice(0, 10);
}

/** Start of the next UTC day — what the client shows as the reset time. */
export function resetsAt(now) {
  const date = new Date(now);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1);
}

function counterKey(bucket, subject, day) {
  return `${KEY_PREFIX}:${bucket}:${subject}:${day}`;
}

async function readCount(kv, key) {
  const raw = await kv.get(key);
  const value = Number.parseInt(raw ?? "0", 10);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

/**
 * Consumes one unit from a counter.
 * @returns {Promise<{ok: boolean, used: number, limit: number, remaining: number, resetsAt: number}>}
 */
export async function consume(kv, { bucket, subject, limit, now = Date.now() }) {
  const day = dayKey(now);
  const key = counterKey(bucket, subject, day);
  const used = await readCount(kv, key);

  if (used >= limit) {
    return { ok: false, used, limit, remaining: 0, resetsAt: resetsAt(now) };
  }

  const next = used + 1;
  await kv.put(key, String(next), { expirationTtl: TTL_SECONDS });

  return { ok: true, used: next, limit, remaining: limit - next, resetsAt: resetsAt(now) };
}

/** Returns a consumed unit after an upstream failure, so errors are not billed to the user. */
export async function refund(kv, { bucket, subject, now = Date.now() }) {
  const day = dayKey(now);
  const key = counterKey(bucket, subject, day);
  const used = await readCount(kv, key);
  if (used <= 0) return;
  await kv.put(key, String(used - 1), { expirationTtl: TTL_SECONDS });
}
