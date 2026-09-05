import { DatabaseSync } from 'node:sqlite';
import { QuotaLedger } from '../src/quota-ledger.js';

export function sqliteStorage(database = new DatabaseSync(':memory:')) {
  return {
    database,
    sql: { exec(query, ...bindings) {
      const rows = database.prepare(query).all(...bindings);
      return { toArray: () => rows };
    } },
    transactionSync(callback) {
      database.exec('BEGIN IMMEDIATE');
      try { const value = callback(); database.exec('COMMIT'); return value; }
      catch (error) { database.exec('ROLLBACK'); throw error; }
    },
  };
}
export function quotaNamespace() {
  const ledgers = new Map();
  return { ledgers, getByName(name) {
    if (!ledgers.has(name)) ledgers.set(name, new QuotaLedger(sqliteStorage()));
    return ledgers.get(name);
  } };
}
export function usageCount(env, bucket, subject, now = Date.now()) {
  const day = new Date(now).toISOString().slice(0, 10);
  const ledger = env.QUOTAS.getByName(`budget-v1:${day}`);
  const sql = bucket === 'global'
    ? "SELECT COUNT(*) AS count FROM reservations WHERE refunded = 0 AND bucket IN ('chat', 'image')"
    : 'SELECT COUNT(*) AS count FROM reservations WHERE refunded = 0 AND bucket = ? AND subject = ?';
  return String(ledger.sql.exec(sql, ...(bucket === 'global' ? [] : [bucket, subject])).toArray()[0].count);
}
