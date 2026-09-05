// Local integration harness only. The production entrypoint is src/index.js.
export { DailyQuota } from '../src/quota-object.js';
export default { async fetch(request, env) {
  const { method, day, args } = await request.json();
  const ledger = env.QUOTAS.getByName(`runtime-test:${day}`);
  if (method === 'reserve') return Response.json(await ledger.reserve(args));
  if (method === 'refund') { await ledger.refund(args.id); return Response.json({ok:true}); }
  if (method === 'snapshot') return Response.json(await ledger.snapshot(args.now, 100));
  return new Response('Not found',{status:404});
} };
