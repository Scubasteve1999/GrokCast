import { DurableObject } from 'cloudflare:workers';
import { QuotaLedger } from './quota-ledger.js';

export class DailyQuota extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ledger = new QuotaLedger(ctx.storage);
    ctx.blockConcurrencyWhile(async () => {
      // Keep old-day reservations long enough for refunds crossing midnight.
      if (await ctx.storage.getAlarm() === null) {
        await ctx.storage.setAlarm(Date.now() + 3 * 24 * 60 * 60 * 1000);
      }
    });
  }
  reserve(args) { return this.ledger.reserve(args); }
  refund(id) { return this.ledger.refund(id); }
  snapshot(now, threshold) { return this.ledger.snapshot(now, threshold); }
  async alarm() { await this.ctx.storage.deleteAll(); }
}
