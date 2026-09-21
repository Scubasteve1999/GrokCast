import assert from "node:assert/strict";
import test from "node:test";
import worker from "../src/index.js";

test("stub path is honest and does not pretend to be a live extract", async () => {
  const response = await worker.fetch(new Request("https://refs.example/v1/agreement?stub=1"));
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.stub, true);
  assert.equal(body.parallel, true);
  assert.equal(body.agreement_tier, "split");
  assert.ok(body.divergence.sentence.includes("timing isn't locked"));
  assert.equal(JSON.stringify(body).toLowerCase().includes("eas"), false);
});

test("a point outside every REFS domain is a quiet miss", async () => {
  const response = await worker.fetch(
    new Request("https://refs.example/v1/agreement?lat=51.5&lon=-0.12&tz=Europe/London"),
  );
  assert.equal(response.status, 404);
  const body = await response.json();
  assert.equal(body.error, "outside_refs_domain");
});

test("health is not the agreement payload", async () => {
  const response = await worker.fetch(new Request("https://refs.example/health"));
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(body.agreement_tier, undefined);
});
