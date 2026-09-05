import assert from 'node:assert/strict';
import test from 'node:test';
import { QuotaLedger, dailyQuota } from '../src/quota-ledger.js';
import { validatedBody } from '../src/request-policy.js';
import { handle } from '../src/worker.js';
import { sqliteStorage, usageCount } from './quota-helpers.js';
import { mintTransaction, proxyRequest, testEnv, TEST_ROOT } from './helpers.js';
const NOW = Date.parse('2026-09-05T12:00:00Z');
const reservation = (overrides = {}) => ({id:crypto.randomUUID(), subject:'subscriber', bucket:'chat', limit:3, globalLimit:5, now:NOW, ...overrides});
const chat = (overrides = {}) => ({model:'grok-3-mini',messages:[{role:'user',content:'Weather?'}],...overrides});
const validate = (body, bucket='chat') => validatedBody(proxyRequest({body:JSON.stringify(body)}),bucket);

test('100 concurrent reservations never exceed the subscriber or global cap', async () => {
  const ledger = new QuotaLedger(sqliteStorage());
  const results = await Promise.all(Array.from({length:100},(_,i)=>Promise.resolve().then(()=>
    ledger.reserve(reservation({subject:`subscriber-${i % 10}`})))));
  assert.equal(results.filter(x=>x.ok).length,5);
  assert.equal(ledger.snapshot(NOW,5).global,5);
  const single = new QuotaLedger(sqliteStorage());
  const perUser = await Promise.all(Array.from({length:100},()=>Promise.resolve().then(()=>single.reserve(reservation()))));
  assert.equal(perUser.filter(x=>x.ok).length,3);
});

test('a denied global reservation consumes no subscriber allowance', () => {
  const ledger = new QuotaLedger(sqliteStorage());
  ledger.reserve(reservation({globalLimit:1}));
  assert.equal(ledger.reserve(reservation({subject:'other',globalLimit:1})).reason,'global');
  assert.equal(ledger.snapshot(NOW,100).subscribers,1);
});

test('duplicate refunds release exactly one reservation and survive re-instantiation', () => {
  const storage = sqliteStorage();let ledger = new QuotaLedger(storage);
  const first=ledger.reserve(reservation());ledger.reserve(reservation());
  ledger.refund(first.reservationID);ledger.refund(first.reservationID);ledger.refund('unknown');
  ledger=new QuotaLedger(storage);
  assert.equal(ledger.snapshot(NOW,100).global,1);
  ledger.refund(first.reservationID);
  assert.equal(ledger.snapshot(NOW,100).global,1);
  assert.equal(ledger.reserve(reservation({id:first.reservationID})).reason,'duplicate');
});

test('transaction errors roll back all reservation writes', () => {
  const storage=sqliteStorage();const ledger=new QuotaLedger(storage);
  const exec=storage.sql.exec;
  storage.sql.exec=(q,...args)=>{const result=exec(q,...args);if(q.startsWith('INSERT'))throw new Error('disk fault');return result;};
  assert.throws(()=>ledger.reserve(reservation()),/disk fault/);
  assert.equal(ledger.snapshot(NOW,10).global,0);
});

test('midnight starts a separate ledger; a late refund targets the original day', () => {
  const env=testEnv();const yesterday=dailyQuota(env,NOW);const today=dailyQuota(env,NOW+86400000);
  const previous=yesterday.reserve(reservation());today.reserve(reservation({now:NOW+86400000}));
  yesterday.refund(previous.reservationID);
  assert.equal(yesterday.snapshot(NOW,10).global,0);
  assert.equal(today.snapshot(NOW+86400000,10).global,1);
});

test('chat, image, and weather budgets stay separate while AI shares one global cap', () => {
  const ledger=new QuotaLedger(sqliteStorage());
  assert.equal(ledger.reserve(reservation({limit:1,globalLimit:2})).ok,true);
  assert.equal(ledger.reserve(reservation({bucket:'image',limit:1,globalLimit:2})).ok,true);
  assert.equal(ledger.reserve(reservation({subject:'other',globalLimit:2})).reason,'global');
  assert.equal(ledger.reserve(reservation({bucket:'owm',limit:1,globalLimit:2})).ok,true);
  assert.equal(ledger.reserve(reservation({bucket:'owm',limit:1,globalLimit:2})).ok,false);
  assert.equal(ledger.snapshot(NOW,100).global,2);
  assert.equal(ledger.snapshot(NOW,100).owm,1);
});

test('real Worker handler admits only 5 of 30 simultaneous subscribers', async () => {
  const env=testEnv({GLOBAL_DAILY_LIMIT:'5'});let upstream=0;
  const tokens=await Promise.all(Array.from({length:30},(_,i)=>mintTransaction({originalTransactionId:String(100+i)})));
  const responses=await Promise.all(tokens.map(transaction=>handle(proxyRequest({transaction}),env,{
    rootCertificate:TEST_ROOT,fetchImpl:async()=>{upstream++;return new Response('{}');},
  })));
  assert.equal(responses.filter(r=>r.status===200).length,5);
  assert.equal(upstream,5);
});

test('invalid requests consume no quota and never reach upstream', async () => {
  const env=testEnv();let upstream=0;const transaction=await mintTransaction();
  const response=await handle(proxyRequest({transaction,body:JSON.stringify(chat({max_tokens:1000000}))}),env,{
    rootCertificate:TEST_ROOT,fetchImpl:async()=>{upstream++;return new Response('{}');},
  });
  assert.equal(response.status,400);assert.equal(upstream,0);
  assert.equal(usageCount(env,'global','__global__'),'0');
});

test('missing quota binding fails closed even when legacy KV is present', async () => {
  const env=testEnv({QUOTAS:undefined});
  const response=await handle(proxyRequest({transaction:await mintTransaction()}),env,{rootCertificate:TEST_ROOT});
  assert.equal(response.status,503);
});

test('current app chat and JPEG vision shapes remain valid; missing output limit is bounded', async () => {
  const normalized=JSON.parse(await validate(chat({stream:true,temperature:0.7})));
  assert.equal(normalized.max_tokens,1024);assert.equal(normalized.stream,true);
  await validate(chat({model:'grok-4.3',max_tokens:1024,messages:[{role:'user',content:[
    {type:'text',text:'Analyze weather'}, {type:'image_url',image_url:{url:'data:image/jpeg;base64,/9j/AA=='}}
  ]}]}));
  const image=JSON.parse(await validate({model:'grok-imagine-image-quality',prompt:'Clouds'},'image'));
  assert.equal(image.n,1);assert.equal(image.response_format,'url');
});

for (const [name,body] of Object.entries({
  model:chat({model:'arbitrary-model'}), tokens:chat({max_tokens:4097}), fractional:chat({max_tokens:1.1}),
  tools:chat({tools:[{type:'web_search'}]}), alternateLimit:chat({max_completion_tokens:1000000}),
  messages:chat({messages:[]}), text:chat({messages:[{role:'user',content:'a'.repeat(32001)}]}),
  remoteImage:chat({model:'grok-4.3',messages:[{role:'user',content:[{type:'image_url',image_url:{url:'https://example.com/image.jpg'}}]}]}),
  role:chat({messages:[{role:'tool',content:'data'}]}), nestedField:chat({messages:[{role:'user',content:'Weather',tools:[]}]}),
})) test(`rejects unsafe ${name}`, async()=>assert.rejects(()=>validate(body)));

test('rejects multi-image output and unsupported image dimensions',async()=>{
  await assert.rejects(()=>validate({model:'grok-imagine-image-quality',prompt:'Clouds',n:2},'image'));
  await assert.rejects(()=>validate({model:'grok-imagine-image-quality',prompt:'Clouds',size:'4096x4096'},'image'));
});

test('limits actual streamed bytes even without a Content-Length header',async()=>{
  const request=new Request('https://proxy.example/v1/chat/completions',{method:'POST',headers:{'Content-Type':'application/json'},
    body:new ReadableStream({start(controller){controller.enqueue(new Uint8Array(4*1024*1024+1));controller.close();}}),duplex:'half'});
  await assert.rejects(()=>validatedBody(request,'chat'),error=>error.status===413);
});

test('rejects malformed JSON, wrong media type, and query overrides',async()=>{
  await assert.rejects(()=>validatedBody(proxyRequest({body:'{'}),'chat'));
  await assert.rejects(()=>validatedBody(new Request('https://proxy.example/v1/chat/completions',{method:'POST',body:'{}'}),'chat'),error=>error.status===415);
  await assert.rejects(()=>validatedBody(proxyRequest({path:'/v1/chat/completions?model=other'}),'chat'));
});

test('ambiguous upstream 5xx stays reserved; explicit 429 releases credit',async()=>{
  for(const status of [500,429]) {
    const env=testEnv();
    const response=await handle(proxyRequest({transaction:await mintTransaction()}),env,{
      rootCertificate:TEST_ROOT,fetchImpl:async()=>new Response('{}',{status}),
    });
    assert.equal(response.status,status);
    assert.equal(usageCount(env,'global','__global__'),status===500?'1':'0');
  }
});

test('cutover date is required and cannot grant quota before the configured UTC day',async()=>{
  const transaction=await mintTransaction();
  for(const start of ['', '2099-01-01', '2026-99-99']) {
    let calls=0;const env=testEnv({QUOTA_START_DAY:start});
    const response=await handle(proxyRequest({transaction}),env,{
      rootCertificate:TEST_ROOT,fetchImpl:async()=>{calls++;return new Response('{}');},
    });
    assert.equal(response.status,503);assert.equal(calls,0);
    assert.equal(usageCount(env,'global','__global__'),'0');
  }
});
