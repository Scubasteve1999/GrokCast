import assert from "node:assert/strict";
import { test } from "node:test";

import {
  expiresRelativeText,
  fetchActiveAlerts,
  isLifeThreatening,
  isSevereEvent,
  isWarning,
  parseAlerts,
} from "../src/nws.ts";

const alert = (over: Record<string, unknown> = {}) => ({
  id: "urn:oid:1.2.3",
  event: "Severe Thunderstorm Warning",
  ...over,
});

test("isSevereEvent gates on warning/watch, matching NWSAlert.isSevereEvent", () => {
  assert.equal(isSevereEvent(alert()), true);
  assert.equal(isSevereEvent(alert({ event: "Tornado Watch" })), true);
  assert.equal(isSevereEvent(alert({ event: "Special Weather Statement" })), false);
  assert.equal(isSevereEvent(alert({ event: "Air Quality Alert" })), false);
});

test("isWarning distinguishes warnings from watches", () => {
  assert.equal(isWarning(alert()), true);
  assert.equal(isWarning(alert({ event: "Tornado Watch" })), false);
});

test("isLifeThreatening matches the Swift event list", () => {
  assert.equal(isLifeThreatening(alert({ event: "Tornado Warning" })), true);
  assert.equal(isLifeThreatening(alert({ event: "Storm Surge Warning" })), true);
  assert.equal(isLifeThreatening(alert({ event: "Flash Flood Emergency" })), true);
  // A Severe Thunderstorm Warning is severe but not on the life-threatening list.
  assert.equal(isLifeThreatening(alert()), false);
});

test("isLifeThreatening promotes any alert marked Extreme severity", () => {
  assert.equal(isLifeThreatening(alert({ event: "Dust Storm Warning" })), false);
  assert.equal(
    isLifeThreatening(alert({ event: "Dust Storm Warning", severity: "Extreme" })),
    true,
  );
});

test("expiresRelativeText formats hours and minutes, and drops expired alerts", () => {
  const now = Date.parse("2026-08-03T12:00:00Z");
  assert.equal(
    expiresRelativeText(alert({ expires: "2026-08-03T14:30:00Z" }), now),
    "Expires in 2h 30m",
  );
  assert.equal(
    expiresRelativeText(alert({ expires: "2026-08-03T12:45:00Z" }), now),
    "Expires in 45m",
  );
  assert.equal(expiresRelativeText(alert({ expires: "2026-08-03T11:00:00Z" }), now), undefined);
  assert.equal(expiresRelativeText(alert()), undefined);
});

test("parseAlerts prefers the NWS feature id and skips features with no event", () => {
  const parsed = parseAlerts({
    features: [
      { id: "urn:oid:real", properties: { event: "Tornado Warning", severity: "Extreme" } },
      { properties: { event: "Flood Watch", expires: "2026-08-03T18:00:00Z" } },
      { properties: {} },
    ],
  });

  assert.equal(parsed.length, 2);
  assert.equal(parsed[0].id, "urn:oid:real");
  // Fallback id shape mirrors NWSService's constructed value.
  assert.equal(parsed[1].id, "nws-Flood Watch-2026-08-03T18:00:00Z");
});

test("fetchActiveAlerts returns [] for the empty-feature response non-US points get", async () => {
  const fetchImpl = (async () =>
    new Response(JSON.stringify({ features: [] }), { status: 200 })) as unknown as typeof fetch;

  assert.deepEqual(await fetchActiveAlerts(48.85, 2.35, fetchImpl), []);
});

test("fetchActiveAlerts identifies itself to NWS and queries the point endpoint", async () => {
  let seenUrl = "";
  let seenAgent: string | null = null;

  const fetchImpl = (async (url: string, init: RequestInit) => {
    seenUrl = url;
    seenAgent = (init.headers as Record<string, string>)["User-Agent"];
    return new Response(JSON.stringify({ features: [] }), { status: 200 });
  }) as unknown as typeof fetch;

  await fetchActiveAlerts(35.5, -97.5, fetchImpl);

  assert.equal(seenUrl, "https://api.weather.gov/alerts/active?point=35.5,-97.5");
  assert.match(seenAgent ?? "", /SpotterCast/);
});

test("fetchActiveAlerts throws on HTTP failure so the caller can stay silent", async () => {
  const fetchImpl = (async () => new Response("nope", { status: 503 })) as unknown as typeof fetch;
  await assert.rejects(() => fetchActiveAlerts(35.5, -97.5, fetchImpl), /NWS 503/);
});
