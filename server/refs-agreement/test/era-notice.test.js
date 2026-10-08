import assert from "node:assert/strict";
import test from "node:test";
import { DEFAULT_ERA_NOTICE, sanitizeEraNotice } from "../src/era-notice.js";
import worker from "../src/index.js";

const slipped = {
  id: "scn-26-48-2026-10-15",
  cutoverUTC: "2026-10-15T12:00:00Z",
  windowStartUTC: "2026-10-07T12:00:00Z",
  windowEndUTC: "2026-10-28T12:00:00Z",
  status: "slipped",
  updatedAt: "2026-10-13T18:00:00Z",
};

function kv(value) {
  return {
    get: async (key) => (key === "current" ? value : null),
  };
}

async function eraNotice(env) {
  return worker.fetch(new Request("https://refs.example/era-notice"), env);
}

test("defaults are the November 3 slip and pass their own validation", () => {
  assert.equal(DEFAULT_ERA_NOTICE.id, "rrfs-2026-11-03");
  assert.equal(DEFAULT_ERA_NOTICE.cutoverUTC, "2026-11-03T12:00:00Z");
  assert.equal(DEFAULT_ERA_NOTICE.windowEndUTC, "2026-11-17T12:00:00Z");
  assert.equal(DEFAULT_ERA_NOTICE.status, "slipped");
  assert.deepEqual(sanitizeEraNotice({ ...DEFAULT_ERA_NOTICE, id: "x" }), {
    ...DEFAULT_ERA_NOTICE,
    id: "x",
  });
});

test("sanitize returns defaults for missing or empty input", () => {
  assert.deepEqual(sanitizeEraNotice(null), DEFAULT_ERA_NOTICE);
  assert.deepEqual(sanitizeEraNotice(""), DEFAULT_ERA_NOTICE);
  assert.deepEqual(sanitizeEraNotice("{"), DEFAULT_ERA_NOTICE);
});

test("sanitize accepts a slipped October 15 payload", () => {
  assert.deepEqual(sanitizeEraNotice(JSON.stringify(slipped)), slipped);
  assert.deepEqual(sanitizeEraNotice(slipped), slipped);
});

test("sanitize rejects out-of-bounds or misordered dates", () => {
  assert.deepEqual(
    sanitizeEraNotice({ ...slipped, cutoverUTC: "2025-10-14T12:00:00Z" }),
    DEFAULT_ERA_NOTICE,
  );
  assert.deepEqual(
    sanitizeEraNotice({ ...slipped, windowEndUTC: "2027-01-01T00:00:00Z" }),
    DEFAULT_ERA_NOTICE,
  );
  assert.deepEqual(
    sanitizeEraNotice({
      ...slipped,
      windowStartUTC: "2026-10-16T12:00:00Z",
      cutoverUTC: "2026-10-15T12:00:00Z",
    }),
    DEFAULT_ERA_NOTICE,
  );
  assert.deepEqual(
    sanitizeEraNotice({ ...slipped, cutoverUTC: "October 15, 2026" }),
    DEFAULT_ERA_NOTICE,
  );
});

test("sanitize rejects a bad status or empty id", () => {
  assert.deepEqual(sanitizeEraNotice({ ...slipped, status: "maybe" }), DEFAULT_ERA_NOTICE);
  assert.deepEqual(sanitizeEraNotice({ ...slipped, id: "  " }), DEFAULT_ERA_NOTICE);
});

test("GET /era-notice returns defaults when KV is missing", async () => {
  const response = await eraNotice({});
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "public, max-age=900");
  assert.deepEqual(await response.json(), DEFAULT_ERA_NOTICE);
});

test("GET /era-notice reads a valid KV value", async () => {
  const response = await eraNotice({ ERA_NOTICE: kv(JSON.stringify(slipped)) });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cache-control"), "public, max-age=900");
  assert.deepEqual(await response.json(), slipped);
});

test("GET /era-notice falls back when KV is invalid", async () => {
  const response = await eraNotice({
    ERA_NOTICE: kv(JSON.stringify({ ...slipped, cutoverUTC: "2025-01-01T00:00:00Z" })),
  });
  assert.deepEqual(await response.json(), DEFAULT_ERA_NOTICE);
});
