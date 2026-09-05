/** Legacy read-only KV reporting and UTC date helpers.
 * Live quotas are exclusively enforced by quota-ledger.js; KV is never a fallback.
 */

const KEY_PREFIX = "usage:v1";

/** Subject used for the account-wide counter, distinct from any transaction id. */
export const GLOBAL_SUBJECT = "__global__";

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

const REPORT_PREFIX = "report:v1";

export function reportKey(day) {
  return `${REPORT_PREFIX}:${day}`;
}

/**
 * The most recent day a rollup was stored for, or null if none exist.
 *
 * Exposed so an external checker can tell whether the cron trigger is still
 * firing. Without it a silently dead cron looks identical to a healthy one:
 * the reports simply stop and nobody notices.
 */
export async function lastReportDay(kv) {
  let latest = null;
  let cursor;

  do {
    const page = await kv.list({ prefix: `${REPORT_PREFIX}:`, cursor });
    for (const { name } of page.keys ?? []) {
      const day = name.slice(REPORT_PREFIX.length + 1);
      if (!latest || day > latest) latest = day;
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);

  return latest;
}

/**
 * Reads a day's usage without consuming anything.
 *
 * Counts subscribers by listing per-bucket keys rather than storing a separate
 * total, so the number cannot drift out of step with the counters it describes.
 * Live admission uses quota-ledger.js; this remains for fixture/legacy report tests.
 */
export async function snapshot(kv, { now = Date.now(), alertThreshold }) {
  const day = dayKey(now);
  const global = await readCount(kv, counterKey("global", GLOBAL_SUBJECT, day));

  // Only the global counter is stored as an aggregate; chat and image totals are
  // summed from the per-subscriber keys that actually exist.
  const subjects = new Set();
  let chat = 0;
  let image = 0;
  let cursor;

  do {
    const page = await kv.list({ prefix: `${KEY_PREFIX}:`, cursor });
    for (const { name } of page.keys ?? []) {
      const [, , bucket, subject, keyDay] = name.split(":");
      if (keyDay !== day || bucket === "global" || subject === GLOBAL_SUBJECT) continue;

      const count = await readCount(kv, name);
      if (bucket === "chat") chat += count;
      if (bucket === "image") image += count;
      subjects.add(subject);
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);

  return {
    day,
    global,
    chat,
    image,
    subscribers: subjects.size,
    threshold: alertThreshold ?? null,
    over: alertThreshold != null && global >= alertThreshold,
  };
}
