import { dayKey, resetsAt } from './usage.js';

// A coordination atom is one day's budget. No network calls or streaming pass through it.
export class QuotaLedger {
  constructor(storage) {
    this.storage = storage;
    this.sql = storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS reservations (
      id TEXT PRIMARY KEY, subject TEXT NOT NULL, bucket TEXT NOT NULL,
      day TEXT NOT NULL, refunded INTEGER NOT NULL DEFAULT 0
    )`);
    this.sql.exec('CREATE INDEX IF NOT EXISTS quota_counts ON reservations(refunded, bucket, subject)');
  }

  reserve({ id, subject, bucket, limit, globalLimit, now }) {
    if (!['chat', 'image', 'owm'].includes(bucket) || !id || !subject ||
        !Number.isSafeInteger(limit) || limit < 1 ||
        !Number.isSafeInteger(globalLimit) || globalLimit < 1 || !Number.isFinite(now)) {
      throw new Error('Invalid quota reservation');
    }
    return this.storage.transactionSync(() => {
      const previous = this.sql.exec('SELECT * FROM reservations WHERE id = ?', id).toArray()[0];
      if (previous) {
        // An ambiguous reservation retry must never create an additional upstream allowance.
        return { ok: false, reason: 'duplicate', limit, remaining: 0, resetsAt: resetsAt(now) };
      }
      const used = this.sql.exec(
        'SELECT COUNT(*) AS count FROM reservations WHERE refunded = 0 AND bucket = ? AND subject = ?',
        bucket, subject).toArray()[0].count;
      const global = this.sql.exec(
        "SELECT COUNT(*) AS count FROM reservations WHERE refunded = 0 AND bucket IN ('chat','image')"
      ).toArray()[0].count;
      const base = { used, limit, remaining: Math.max(0, limit - used), resetsAt: resetsAt(now) };
      if (used >= limit) return { ...base, ok: false, reason: 'subscriber' };
      if (bucket !== 'owm' && global >= globalLimit) return { ...base, ok: false, reason: 'global' };
      this.sql.exec('INSERT INTO reservations(id, subject, bucket, day) VALUES (?, ?, ?, ?)',
        id, subject, bucket, dayKey(now));
      return { ...base, used: used + 1, ok: true, remaining: limit - used - 1, reservationID: id };
    });
  }

  refund(id) {
    // One transaction releases both quotas; repeating this cannot create extra credit.
    return this.storage.transactionSync(() => {
      this.sql.exec('UPDATE reservations SET refunded = 1 WHERE id = ? AND refunded = 0', id);
    });
  }

  snapshot(now, alertThreshold) {
    const totals = this.sql.exec(`SELECT
      COALESCE(SUM(bucket = 'chat'), 0) AS chat,
      COALESCE(SUM(bucket = 'image'), 0) AS image,
      COALESCE(SUM(bucket = 'owm'), 0) AS owm,
      COUNT(DISTINCT CASE WHEN bucket != 'owm' THEN subject END) AS subscribers
      FROM reservations WHERE refunded = 0`).toArray()[0];
    const global = totals.chat + totals.image;
    return { ...totals, day: dayKey(now), global, threshold: alertThreshold,
      over: alertThreshold != null && global >= alertThreshold };
  }
}

export function dailyQuota(env, now) {
  if (!env.QUOTAS) throw new Error('Quota store is not bound');
  return env.QUOTAS.getByName(`budget-v1:${dayKey(now)}`);
}

export async function quotaSnapshot(env, { now, alertThreshold }) {
  return dailyQuota(env, now).snapshot(now, alertThreshold);
}

// Explicit cutover gate prevents a new empty ledger silently granting a second daily budget.
export function quotaActive(env, now) {
  const day = env.QUOTA_START_DAY;
  if (typeof day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day)) return false;
  const parsed = Date.parse(day + 'T00:00:00Z');
  return Number.isFinite(parsed) && dayKey(parsed) === day && dayKey(now) >= day;
}
