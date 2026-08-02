import assert from "node:assert/strict";
import test from "node:test";

import { snapshot } from "../src/usage.js";
import { handle, runDailyRollup } from "../src/worker.js";
import { memoryKV, proxyRequest, testEnv } from "./helpers.js";

const NOON = Date.parse("2026-08-02T12:00:00Z");
const DAY = "2026-08-02";

function usageKV(entries) {
  return memoryKV(entries);
}

test("snapshot sums per-subscriber buckets and reads the global counter", async () => {
  const kv = usageKV({
    [`usage:v1:chat:sub-1:${DAY}`]: "10",
    [`usage:v1:chat:sub-2:${DAY}`]: "5",
    [`usage:v1:image:sub-1:${DAY}`]: "2",
    [`usage:v1:global:__global__:${DAY}`]: "17",
  });

  const result = await snapshot(kv, { now: NOON, alertThreshold: 500 });

  assert.equal(result.day, DAY);
  assert.equal(result.global, 17);
  assert.equal(result.chat, 15);
  assert.equal(result.image, 2);
  assert.equal(result.subscribers, 2, "one subscriber counted per id, not per bucket");
  assert.equal(result.over, false);
});

test("snapshot pages through more keys than fit in one KV list call", async () => {
  const entries = {};
  for (let i = 0; i < 9; i++) entries[`usage:v1:chat:sub-${i}:${DAY}`] = "1";
  entries[`usage:v1:global:__global__:${DAY}`] = "9";

  const result = await snapshot(usageKV(entries), { now: NOON, alertThreshold: 500 });

  assert.equal(result.subscribers, 9);
  assert.equal(result.chat, 9);
});

test("snapshot ignores other days", async () => {
  const kv = usageKV({
    [`usage:v1:chat:sub-1:${DAY}`]: "3",
    "usage:v1:chat:sub-1:2026-08-01": "99",
    [`usage:v1:global:__global__:${DAY}`]: "3",
  });

  const result = await snapshot(kv, { now: NOON, alertThreshold: 500 });
  assert.equal(result.chat, 3);
  assert.equal(result.global, 3);
});

test("over flips only at the threshold", async () => {
  const below = await snapshot(usageKV({ [`usage:v1:global:__global__:${DAY}`]: "499" }), {
    now: NOON,
    alertThreshold: 500,
  });
  assert.equal(below.over, false);

  const at = await snapshot(usageKV({ [`usage:v1:global:__global__:${DAY}`]: "500" }), {
    now: NOON,
    alertThreshold: 500,
  });
  assert.equal(at.over, true);
});

test("the rollup stores a durable report the counters' own TTL would lose", async () => {
  const env = testEnv({
    USAGE: usageKV({
      [`usage:v1:chat:sub-1:${DAY}`]: "4",
      [`usage:v1:global:__global__:${DAY}`]: "4",
    }),
  });

  const usage = await runDailyRollup(env, NOON);

  assert.equal(usage.global, 4);
  const stored = JSON.parse(env.USAGE.store.get(`report:v1:${DAY}`));
  assert.equal(stored.global, 4);
  assert.equal(stored.day, DAY);
});

test("status requires the shared secret", async () => {
  const env = testEnv();
  const request = proxyRequest({ path: "/v1/status", method: "GET", secret: "wrong" });
  const response = await handle(request, env, { now: NOON });
  assert.equal(response.status, 401);
});

test("status reports usage without consuming any allowance", async () => {
  const env = testEnv({
    USAGE: usageKV({
      [`usage:v1:chat:sub-1:${DAY}`]: "7",
      [`usage:v1:global:__global__:${DAY}`]: "7",
    }),
  });

  const response = await handle(
    proxyRequest({ path: "/v1/status", method: "GET" }),
    env,
    { now: NOON }
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.usage.global, 7);
  assert.equal(body.usage.threshold, 500);
  assert.equal(body.usage.over, false);

  // Reading must not move the counters it reports on.
  assert.equal(env.USAGE.store.get(`usage:v1:global:__global__:${DAY}`), "7");
});

test("status surfaces the kill switch", async () => {
  const env = testEnv({ DISABLED: "1" });
  const response = await handle(
    proxyRequest({ path: "/v1/status", method: "GET" }),
    env,
    { now: NOON }
  );
  assert.equal((await response.json()).disabled, true);
});

test("alert is unauthenticated but reveals no usage figures", async () => {
  const env = testEnv({
    USAGE: usageKV({
      [`usage:v1:chat:sub-1:${DAY}`]: "600",
      [`usage:v1:global:__global__:${DAY}`]: "600",
    }),
  });

  const response = await handle(
    proxyRequest({ path: "/v1/alert", method: "GET", secret: null }),
    env,
    { now: NOON }
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.over, true);
  assert.equal(body.day, DAY);
  // The point of this endpoint: an external checker needs no credential, so it
  // must not hand out the numbers a credential would buy.
  assert.deepEqual(Object.keys(body).sort(), ["day", "over"]);
});

test("alert stays false below the threshold", async () => {
  const env = testEnv({
    USAGE: usageKV({ [`usage:v1:global:__global__:${DAY}`]: "12" }),
  });
  const response = await handle(
    proxyRequest({ path: "/v1/alert", method: "GET", secret: null }),
    env,
    { now: NOON }
  );
  assert.equal((await response.json()).over, false);
});
