import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildAlertBody,
  buildAlertPayload,
  buildAlertSubtitle,
  buildMorningBriefPayload,
  buildSilentRefreshPayload,
  morningBriefGreeting,
  morningBriefSubtitle,
} from "../src/notifications.ts";

const NOW = Date.parse("2026-08-03T12:00:00Z");

test("buildAlertSubtitle joins area and expiry the way the Swift builder does", () => {
  assert.equal(
    buildAlertSubtitle(
      {
        id: "1",
        event: "Tornado Warning",
        areaDesc: "Cleveland County, OK",
        expires: "2026-08-03T12:45:00Z",
      },
      NOW,
    ),
    "Cleveland County, OK · Expires in 45m",
  );
});

test("buildAlertSubtitle truncates area to 80 characters", () => {
  const subtitle = buildAlertSubtitle({ id: "1", event: "X", areaDesc: "A".repeat(200) }, NOW);
  assert.equal(subtitle.length, 80);
});

test("buildAlertBody prefers instruction, then headline, then description", () => {
  const base = { id: "1", event: "Tornado Warning" };
  assert.equal(
    buildAlertBody({ ...base, instruction: "Take cover", headline: "H", description: "D" }),
    "Take cover",
  );
  assert.equal(buildAlertBody({ ...base, headline: "H", description: "D" }), "H");
  assert.equal(buildAlertBody({ ...base, description: "D" }), "D");
  assert.equal(buildAlertBody(base), "Tap to view alert details in DayCast.");
});

test("buildAlertBody caps at 300 characters", () => {
  assert.equal(
    buildAlertBody({ id: "1", event: "X", instruction: "A".repeat(500) }).length,
    300,
  );
});

test("life-threatening alerts get the warning prefix and the critical category", () => {
  const payload = buildAlertPayload(
    { id: "urn:1", event: "Tornado Warning", severity: "Extreme" },
    { soundsEnabled: true, now: NOW },
  );

  assert.equal(payload.aps.alert.title, "⚠️ Tornado Warning");
  assert.equal(payload.aps.category, "GROKCAST_CRITICAL_ALERT");
  assert.equal(payload.aps["thread-id"], "grokcast-severe-alerts");
  assert.equal(payload.aps["interruption-level"], "time-sensitive");
  assert.equal(payload.deepLink, "grokcast://alerts");
  assert.equal(payload.alertId, "urn:1");
  assert.equal(payload.severity, "Extreme");
});

test("ordinary severe alerts keep an unprefixed title and the standard category", () => {
  const payload = buildAlertPayload(
    { id: "urn:2", event: "Severe Thunderstorm Warning" },
    { soundsEnabled: true, now: NOW },
  );

  assert.equal(payload.aps.alert.title, "Severe Thunderstorm Warning");
  assert.equal(payload.aps.category, "GROKCAST_SEVERE_ALERT");
});

test("sound is omitted when the device reports sounds disabled", () => {
  const on = buildAlertPayload({ id: "1", event: "Tornado Warning" }, { soundsEnabled: true });
  const off = buildAlertPayload({ id: "1", event: "Tornado Warning" }, { soundsEnabled: false });

  assert.equal(on.aps.sound, "default");
  assert.equal(off.aps.sound, undefined);
});

test("morningBriefGreeting matches the Swift hour bands", () => {
  assert.equal(morningBriefGreeting(7, "Norman"), "Good morning — Norman");
  assert.equal(morningBriefGreeting(9, "Norman"), "Good morning — Norman");
  assert.equal(morningBriefGreeting(10, "Norman"), "Morning update — Norman");
  assert.equal(morningBriefGreeting(11, "Norman"), "Morning update — Norman");
  assert.equal(morningBriefGreeting(14, "Norman"), "Weather brief — Norman");
  assert.equal(morningBriefGreeting(7), "Good morning — your area");
});

test("morningBriefSubtitle degrades cleanly as fields drop out", () => {
  assert.equal(morningBriefSubtitle("72°", "Clear"), "72° · Clear");
  assert.equal(morningBriefSubtitle("72°", undefined), "72°");
  assert.equal(morningBriefSubtitle(undefined, "Clear"), "Clear");
  assert.equal(morningBriefSubtitle(undefined, undefined), "");
});

test("the morning brief falls back to the app's copy when there is no brief text", () => {
  const payload = buildMorningBriefPayload({ hour: 7, soundsEnabled: true });
  assert.equal(payload.aps.alert.body, "Open DayCast for today's weather and AI take.");
  assert.equal(payload.aps["thread-id"], "grokcast-morning-brief");
  assert.equal(payload.deepLink, "grokcast://today");
});

test("brief bodies are trimmed and capped at 220 characters", () => {
  const payload = buildMorningBriefPayload({
    hour: 7,
    briefBody: `   ${"B".repeat(400)}   `,
    soundsEnabled: true,
  });
  assert.equal(payload.aps.alert.body.length, 220);
});

test("whitespace-only brief text uses the fallback rather than an empty body", () => {
  const payload = buildMorningBriefPayload({ hour: 7, briefBody: "   \n ", soundsEnabled: true });
  assert.equal(payload.aps.alert.body, "Open DayCast for today's weather and AI take.");
});

test("the silent payload carries content-available and nothing user-visible", () => {
  const payload = buildSilentRefreshPayload();
  assert.deepEqual(payload, { aps: { "content-available": 1 } });
});
