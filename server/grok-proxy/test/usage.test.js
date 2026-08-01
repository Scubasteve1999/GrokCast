import assert from "node:assert/strict";
import test from "node:test";

import { consume, dayKey, refund, resetsAt } from "../src/usage.js";
import { memoryKV } from "./helpers.js";

const NOON = Date.parse("2026-08-01T12:00:00Z");

test("consume counts up to the limit and then refuses", async () => {
  const kv = memoryKV();
  const request = { bucket: "chat", subject: "sub-1", limit: 3, now: NOON };

  for (let i = 1; i <= 3; i++) {
    const result = await consume(kv, request);
    assert.equal(result.ok, true);
    assert.equal(result.used, i);
    assert.equal(result.remaining, 3 - i);
  }

  const blocked = await consume(kv, request);
  assert.equal(blocked.ok, false);
  assert.equal(blocked.remaining, 0);
});

test("chat and image budgets are independent", async () => {
  const kv = memoryKV();
  await consume(kv, { bucket: "image", subject: "sub-1", limit: 1, now: NOON });

  const blockedImage = await consume(kv, { bucket: "image", subject: "sub-1", limit: 1, now: NOON });
  assert.equal(blockedImage.ok, false);

  const chat = await consume(kv, { bucket: "chat", subject: "sub-1", limit: 1, now: NOON });
  assert.equal(chat.ok, true, "an exhausted image budget must not block chat");
});

test("subscribers do not share a counter", async () => {
  const kv = memoryKV();
  await consume(kv, { bucket: "chat", subject: "sub-1", limit: 1, now: NOON });

  const other = await consume(kv, { bucket: "chat", subject: "sub-2", limit: 1, now: NOON });
  assert.equal(other.ok, true);
});

test("the counter rolls over at the UTC day boundary", async () => {
  const kv = memoryKV();
  const beforeMidnight = Date.parse("2026-08-01T23:59:00Z");
  const afterMidnight = Date.parse("2026-08-02T00:01:00Z");

  await consume(kv, { bucket: "chat", subject: "sub-1", limit: 1, now: beforeMidnight });
  const blocked = await consume(kv, { bucket: "chat", subject: "sub-1", limit: 1, now: beforeMidnight });
  assert.equal(blocked.ok, false);

  const nextDay = await consume(kv, { bucket: "chat", subject: "sub-1", limit: 1, now: afterMidnight });
  assert.equal(nextDay.ok, true);
});

test("refund releases a consumed unit and never goes negative", async () => {
  const kv = memoryKV();
  const request = { bucket: "chat", subject: "sub-1", limit: 1, now: NOON };

  await consume(kv, request);
  await refund(kv, { bucket: "chat", subject: "sub-1", now: NOON });
  assert.equal((await consume(kv, request)).ok, true);

  await refund(kv, { bucket: "chat", subject: "sub-2", now: NOON });
  assert.equal(await kv.get("usage:v1:chat:sub-2:2026-08-01"), null);
});

test("resetsAt is the next UTC midnight", () => {
  assert.equal(new Date(resetsAt(NOON)).toISOString(), "2026-08-02T00:00:00.000Z");
  assert.equal(dayKey(NOON), "2026-08-01");
});

test("a corrupted counter value is treated as zero rather than crashing", async () => {
  const kv = memoryKV({ "usage:v1:chat:sub-1:2026-08-01": "not-a-number" });
  const result = await consume(kv, { bucket: "chat", subject: "sub-1", limit: 2, now: NOON });
  assert.equal(result.ok, true);
  assert.equal(result.used, 1);
});
