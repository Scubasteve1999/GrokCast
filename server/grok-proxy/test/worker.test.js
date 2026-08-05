import assert from "node:assert/strict";
import test from "node:test";

import { handle } from "../src/worker.js";
import { fixtures, mintTransaction, proxyRequest, TEST_ROOT, testEnv } from "./helpers.js";

/** Records what reached xAI and replays a canned response. */
function stubUpstream({ status = 200, body = '{"ok":true}', headers = {} } = {}) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return new Response(body, {
      status,
      headers: { "Content-Type": "application/json", ...headers },
    });
  };
  return { calls, fetchImpl };
}

async function call(request, { env = testEnv(), upstream = stubUpstream() } = {}) {
  const response = await handle(request, env, {
    rootCertificate: TEST_ROOT,
    fetchImpl: upstream.fetchImpl,
  });
  return { response, env, upstream };
}

test("health needs no credentials and leaks nothing", async () => {
  const { response } = await call(proxyRequest({ path: "/v1/health", method: "GET" }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, disabled: false });
});

test("an unlisted path never reaches xAI", async () => {
  const upstream = stubUpstream();
  const { response } = await call(
    proxyRequest({ path: "/v1/models", transaction: await mintTransaction() }),
    { upstream }
  );
  assert.equal(response.status, 404);
  assert.equal(upstream.calls.length, 0);
});

test("a wrong shared secret is rejected before the transaction is read", async () => {
  const { response } = await call(proxyRequest({ secret: "wrong", transaction: "irrelevant" }));
  assert.equal(response.status, 401);
});

test("a missing transaction is rejected even with the right secret", async () => {
  const { response } = await call(proxyRequest());
  assert.equal(response.status, 403);
  assert.match((await response.json()).error.message, /Pro required/);
});

test("a transaction from an untrusted chain is rejected", async () => {
  const forged = await mintTransaction({
    chain: [fixtures.rogueLeaf, fixtures.rogueRoot],
    privateKey: fixtures.rogueLeafPrivateKey,
  });
  const upstream = stubUpstream();
  const { response } = await call(proxyRequest({ transaction: forged }), { upstream });

  assert.equal(response.status, 403);
  assert.equal(upstream.calls.length, 0);
});

test("a verified subscriber is forwarded with the server key and usage headers", async () => {
  const upstream = stubUpstream();
  const { response } = await call(
    proxyRequest({ transaction: await mintTransaction() }),
    { upstream }
  );

  assert.equal(response.status, 200);
  assert.equal(upstream.calls.length, 1);
  assert.equal(upstream.calls[0].url, "https://api.x.ai/v1/chat/completions");
  assert.equal(upstream.calls[0].init.headers.get("Authorization"), "Bearer xai-test-server-key");
  assert.equal(response.headers.get("X-DayCast-Limit"), "3");
  assert.equal(response.headers.get("X-DayCast-Remaining"), "2");
  assert.ok(response.headers.get("X-DayCast-Reset"));
});

test("the proxy secret and transaction are never forwarded upstream", async () => {
  const upstream = stubUpstream();
  await call(proxyRequest({ transaction: await mintTransaction() }), { upstream });

  const forwarded = upstream.calls[0].init.headers;
  assert.equal(forwarded.get("X-DayCast-Transaction"), null);
  assert.notEqual(forwarded.get("Authorization"), "Bearer test-proxy-secret");
});

test("the per-subscriber daily cap returns 429 with a reset time", async () => {
  const env = testEnv();
  const upstream = stubUpstream();
  const transaction = await mintTransaction();

  for (let i = 0; i < 3; i++) {
    const { response } = await call(proxyRequest({ transaction }), { env, upstream });
    assert.equal(response.status, 200);
  }

  const { response } = await call(proxyRequest({ transaction }), { env, upstream });
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error.type, "daily_limit_exceeded");
  assert.ok(response.headers.get("X-DayCast-Reset"));
  assert.equal(upstream.calls.length, 3, "the capped request must not reach xAI");
});

test("image generation has its own budget", async () => {
  const env = testEnv();
  const upstream = stubUpstream();
  const transaction = await mintTransaction();
  const image = () => proxyRequest({ path: "/v1/images/generations", transaction });

  assert.equal((await call(image(), { env, upstream })).response.status, 200);
  assert.equal((await call(image(), { env, upstream })).response.status, 200);
  assert.equal((await call(image(), { env, upstream })).response.status, 429);

  const chat = await call(proxyRequest({ transaction }), { env, upstream });
  assert.equal(chat.response.status, 200, "chat keeps its own allowance");
});

test("the global ceiling shields the bill and refunds the user's credit", async () => {
  const env = testEnv({ GLOBAL_DAILY_LIMIT: "1" });
  const upstream = stubUpstream();
  const transaction = await mintTransaction();

  assert.equal((await call(proxyRequest({ transaction }), { env, upstream })).response.status, 200);

  const { response } = await call(proxyRequest({ transaction }), { env, upstream });
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.type, "service_capacity");
  assert.equal(env.USAGE.store.get("usage:v1:chat:2000000800000001:" + new Date().toISOString().slice(0, 10)), "1");
});

test("the kill switch stops everything without touching xAI", async () => {
  const env = testEnv({ DISABLED: "1" });
  const upstream = stubUpstream();
  const { response } = await call(proxyRequest({ transaction: await mintTransaction() }), {
    env,
    upstream,
  });

  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.type, "service_disabled");
  assert.equal(upstream.calls.length, 0);
});

test("an upstream rejection is not billed to the subscriber", async () => {
  const env = testEnv();
  const upstream = stubUpstream({ status: 400, body: '{"error":{"message":"bad model"}}' });
  const transaction = await mintTransaction();

  const { response } = await call(proxyRequest({ transaction }), { env, upstream });
  assert.equal(response.status, 400);

  const day = new Date().toISOString().slice(0, 10);
  assert.equal(env.USAGE.store.get(`usage:v1:chat:2000000800000001:${day}`), "0");
});

test("an upstream network failure returns 502 and refunds", async () => {
  const env = testEnv();
  const failing = {
    calls: [],
    fetchImpl: async () => {
      throw new TypeError("network down");
    },
  };

  const { response } = await call(proxyRequest({ transaction: await mintTransaction() }), {
    env,
    upstream: failing,
  });

  assert.equal(response.status, 502);
  const day = new Date().toISOString().slice(0, 10);
  assert.equal(env.USAGE.store.get(`usage:v1:chat:2000000800000001:${day}`), "0");
});

test("a missing KV binding fails closed", async () => {
  const env = testEnv({ USAGE: undefined });
  const { response } = await call(proxyRequest({ transaction: await mintTransaction() }), { env });
  assert.equal(response.status, 503);
});

test("a missing xAI key fails closed", async () => {
  const env = testEnv({ XAI_API_KEY: "" });
  const { response } = await call(proxyRequest({ transaction: await mintTransaction() }), { env });
  assert.equal(response.status, 503);
});

test("GET is refused on a forwarding route", async () => {
  const { response } = await call(
    proxyRequest({ method: "GET", body: undefined, transaction: await mintTransaction() })
  );
  assert.equal(response.status, 405);
});
