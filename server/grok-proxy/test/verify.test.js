import { usageCount } from "./quota-helpers.js";
import assert from "node:assert/strict";
import test from "node:test";

import { handle } from "../src/worker.js";
import { chanceWords, HARMFUL_THRESHOLD } from "../src/verify.js";
import { mintTransaction, proxyRequest, TEST_ROOT, testEnv } from "./helpers.js";

/** Replays a canned TypeSafe answer and records what was sent. */
function stubTypeSafe({ status = 200, harmful = 0.02, unsupported, body } = {}) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init, sent: JSON.parse(init.body) });
    const answers = { harmful_advice: { type: "noul", noul: harmful } };
    if (unsupported !== undefined) answers.unsupported_precipitation = { type: "noul", noul: unsupported };
    return new Response(body ?? JSON.stringify({ model: "jev-1.14.0", answers, usage: { input_tokens: 480 } }), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  };
  return { calls, fetchImpl };
}

function verifyEnv(overrides = {}) {
  return testEnv({ TYPESAFE_API_KEY: "ts-test-key", ...overrides });
}

async function verify(payload, { env = verifyEnv(), upstream = stubTypeSafe(), transaction, secret } = {}) {
  const request = proxyRequest({
    path: "/v1/verify",
    secret,
    transaction: transaction === undefined ? await mintTransaction() : transaction,
    body: JSON.stringify(payload),
  });
  const response = await handle(request, env, { rootCertificate: TEST_ROOT, fetchImpl: upstream.fetchImpl });
  return { response, env, upstream };
}

const BRIEF = { kind: "brief", text: "Please don't ignore the warning. Get to your basement now." };
const RADAR = {
  kind: "radar",
  text: "Heavy rain is pounding downtown Austin at the moment.",
  pin: { location: "Austin", condition: "Partly cloudy", precipitation_chance: 25 },
};

test("a brief is checked for harmful advice only, with the server key and a pinned model", async () => {
  const { response, upstream } = await verify(BRIEF);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    verdict: "pass", reasons: [], scores: { harmful_advice: 0.02 }, model: "jev-1.14.0",
  });
  const [call] = upstream.calls;
  assert.equal(call.url, "https://api.typesafe.ai/v1/systemone");
  assert.equal(call.init.headers.Authorization, "Bearer ts-test-key");
  assert.equal(call.sent.model, "jev-1.14.0", "never an alias: thresholds were tuned on this version");
  assert.deepEqual(Object.keys(call.sent.questions), ["harmful_advice"]);
  assert.deepEqual(call.sent.state, { text: BRIEF.text });
});

test("the proxy secret and transaction never reach TypeSafe", async () => {
  const { upstream } = await verify(BRIEF);
  const sent = JSON.stringify(upstream.calls[0]);
  assert.ok(!sent.includes("test-proxy-secret"));
  assert.ok(!sent.includes("X-DayCast-Transaction"));
});

test("radar sends the pin with the chance bucketed into words and blocks an invented claim", async () => {
  const upstream = stubTypeSafe({ harmful: 0.01, unsupported: 0.97 });
  const { response } = await verify(RADAR, { upstream });

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.verdict, "block");
  assert.deepEqual(body.reasons, ["unsupported_precipitation"]);
  assert.deepEqual(upstream.calls[0].sent.state.pin_forecast, {
    location: "Austin", condition: "Partly cloudy", chance_of_precipitation: "25% (slight chance)",
  });
  assert.deepEqual(Object.keys(upstream.calls[0].sent.questions), ["harmful_advice", "unsupported_precipitation"]);
});

test("harmful advice blocks at the threshold and passes just below it", async () => {
  const at = await verify(BRIEF, { upstream: stubTypeSafe({ harmful: HARMFUL_THRESHOLD }) });
  assert.deepEqual((await at.response.json()).reasons, ["harmful_advice"]);

  const below = await verify(BRIEF, { upstream: stubTypeSafe({ harmful: HARMFUL_THRESHOLD - 0.01 }) });
  assert.equal((await below.response.json()).verdict, "pass");
});

test("chance buckets: none, slight, chance, likely", () => {
  assert.equal(chanceWords(0), "0% (none)");
  assert.equal(chanceWords(29), "29% (slight chance)");
  assert.equal(chanceWords(30), "30% (chance)");
  assert.equal(chanceWords(60), "60% (likely)");
});

test("verify requires Pro and the shared secret before reaching TypeSafe", async () => {
  const upstream = stubTypeSafe();
  assert.equal((await verify(BRIEF, { upstream, transaction: null })).response.status, 403);
  assert.equal((await verify(BRIEF, { upstream, secret: "wrong" })).response.status, 401);
  assert.equal(upstream.calls.length, 0);
});

test("missing key and either kill switch fail closed with 503 and no upstream call", async () => {
  const upstream = stubTypeSafe();
  for (const env of [
    verifyEnv({ TYPESAFE_API_KEY: undefined }),
    verifyEnv({ VERIFY_DISABLED: "1" }),
    verifyEnv({ DISABLED: "1" }),
  ]) {
    assert.equal((await verify(BRIEF, { env, upstream })).response.status, 503);
  }
  assert.equal(upstream.calls.length, 0);
});

test("invalid bodies are rejected without spending quota", async () => {
  const env = verifyEnv();
  const upstream = stubTypeSafe();
  const bad = [
    { kind: "chat", text: "hi" },
    { kind: "radar", text: "hi" },
    { ...RADAR, pin: { ...RADAR.pin, precipitation_chance: 101 } },
    { ...RADAR, pin: { ...RADAR.pin, precipitation_chance: "25" } },
    { kind: "brief", text: "x".repeat(4001) },
    { kind: "brief", text: "   " },
    { ...BRIEF, model: "jev-latest" },
    { ...BRIEF, pin: RADAR.pin },
  ];
  for (const payload of bad) {
    const { response } = await verify(payload, { env, upstream });
    assert.equal(response.status, 400, JSON.stringify(payload).slice(0, 60));
  }
  assert.equal(upstream.calls.length, 0);
  assert.equal(usageCount(env, "verify", "2000000800000001"), "0");
});

test("verify has its own daily budget and spends neither chat nor the global AI cap", async () => {
  const env = verifyEnv({ DAILY_VERIFY_LIMIT: "2" });
  const upstream = stubTypeSafe();
  assert.equal((await verify(BRIEF, { env, upstream })).response.status, 200);
  assert.equal((await verify(BRIEF, { env, upstream })).response.status, 200);
  const capped = await verify(BRIEF, { env, upstream });

  assert.equal(capped.response.status, 429);
  assert.equal(upstream.calls.length, 2);
  assert.equal(usageCount(env, "chat", "2000000800000001"), "0");
  assert.equal(usageCount(env, "global"), "0");
});

test("an exhausted global AI cap does not block verification", async () => {
  const env = verifyEnv({ GLOBAL_DAILY_LIMIT: "1" });
  const chat = await handle(proxyRequest({ transaction: await mintTransaction() }), env, {
    rootCertificate: TEST_ROOT,
    fetchImpl: async () => new Response("{}", { status: 200 }),
  });
  assert.equal(chat.status, 200);
  assert.equal((await verify(BRIEF, { env })).response.status, 200);
});

test("TypeSafe trouble is a 502; an explicit 4xx refunds, a 5xx stays reserved", async () => {
  const env = verifyEnv();
  const rejected = await verify(BRIEF, { env, upstream: stubTypeSafe({ status: 429 }) });
  assert.equal(rejected.response.status, 502);
  assert.equal(usageCount(env, "verify", "2000000800000001"), "0");

  const failed = await verify(BRIEF, { env, upstream: stubTypeSafe({ status: 500 }) });
  assert.equal(failed.response.status, 502);
  assert.equal(usageCount(env, "verify", "2000000800000001"), "1");

  const malformed = await verify(BRIEF, { env, upstream: stubTypeSafe({ body: '{"answers":{}}' }) });
  assert.equal(malformed.response.status, 502);
});

test("a network failure is a 502, not a thrown error", async () => {
  const upstream = { calls: [], fetchImpl: async () => { throw new TypeError("network down"); } };
  assert.equal((await verify(BRIEF, { upstream })).response.status, 502);
});

test("GET is not allowed", async () => {
  const env = verifyEnv();
  const response = await handle(proxyRequest({ path: "/v1/verify", method: "GET" }), env, {
    rootCertificate: TEST_ROOT,
  });
  assert.equal(response.status, 405);
});
