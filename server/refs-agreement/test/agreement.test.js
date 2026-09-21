import assert from "node:assert/strict";
import test from "node:test";
import {
  classify,
  divergenceSentence,
  parallelAt,
  stubPayload,
  hourLabel,
  rangePhrase,
} from "../src/agreement.js";

const zone = "America/Chicago";
const hour = (iso) => new Date(iso);

function refs(pairs) {
  return pairs.map(([iso, easPercent]) => ({ valid: hour(iso), easPercent }));
}

test("dry consensus has no window and no soft peak", () => {
  const payload = classify(
    refs([
      ["2026-09-21T18:00:00Z", 4],
      ["2026-09-21T19:00:00Z", 8],
      ["2026-09-21T20:00:00Z", 2],
    ]),
    [],
    zone,
    { refsCycle: "2026-09-21T12:00:00Z", hrrrCycle: "2026-09-21T17:00:00Z", domain: "conus", asOf: hour("2026-09-21T17:30:00Z") },
  );
  assert.equal(payload.agreement_tier, "dry_consensus");
  assert.equal(payload.timing_window, undefined);
  assert.equal(payload.divergence, undefined);
  assert.equal(JSON.stringify(payload).includes("soft_peak"), false);
  assert.deepEqual(payload.sources.labels, ["REFS", "HRRR"]);
  assert.equal(payload.parallel, true);
});

test("locked window is one or two hours and keeps the soft peak inside it", () => {
  const payload = classify(
    refs([
      ["2026-09-21T19:00:00Z", 12],
      ["2026-09-21T20:00:00Z", 72],
      ["2026-09-21T21:00:00Z", 61],
      ["2026-09-21T22:00:00Z", 5],
    ]),
    [{ valid: hour("2026-09-21T20:00:00Z"), apcpMillimeters: 1 }],
    zone,
    { refsCycle: "2026-09-21T12:00:00Z", domain: "conus", asOf: hour("2026-09-21T18:00:00Z") },
  );
  assert.equal(payload.agreement_tier, "locked");
  assert.equal(payload.timing_window.width_hours, 2);
  assert.equal(payload.timing_window.start_local.endsWith(":00:00-05:00"), true);
  assert.ok(payload.timing_window.soft_peak_local);
  assert.equal(payload.divergence, undefined);
  assert.equal(JSON.stringify(payload).toLowerCase().includes("eas"), false);
});

test("likely window is a few hours with a real peak", () => {
  const payload = classify(
    refs([
      ["2026-09-21T19:00:00Z", 44],
      ["2026-09-21T20:00:00Z", 51],
      ["2026-09-21T21:00:00Z", 40],
    ]),
    null,
    zone,
    { refsCycle: "2026-09-21T12:00:00Z", domain: "conus", asOf: hour("2026-09-21T18:00:00Z") },
  );
  assert.equal(payload.agreement_tier, "likely_window");
  assert.equal(payload.timing_window.width_hours, 3);
  assert.deepEqual(payload.sources.labels, ["REFS"]);
  assert.equal(payload.sources.hrrr_cycle, undefined);
});

test("wide window when the wet hours stretch out", () => {
  const payload = classify(
    refs([
      ["2026-09-21T18:00:00Z", 31],
      ["2026-09-21T19:00:00Z", 33],
      ["2026-09-21T22:00:00Z", 36],
      ["2026-09-21T23:00:00Z", 31],
    ]),
    [],
    zone,
    { refsCycle: "2026-09-21T12:00:00Z", domain: "conus", asOf: hour("2026-09-21T17:00:00Z") },
  );
  assert.equal(payload.agreement_tier, "wide_window");
  assert.ok(payload.timing_window.width_hours >= 5);
});

test("split when the hourly peak sits outside the ensemble window", () => {
  const payload = classify(
    refs([
      ["2026-09-21T19:00:00Z", 48],
      ["2026-09-21T20:00:00Z", 62],
      ["2026-09-21T21:00:00Z", 40],
    ]),
    [{ valid: hour("2026-09-21T18:00:00Z"), apcpMillimeters: 2.4 }],
    zone,
    {
      refsCycle: "2026-09-21T12:00:00Z",
      hrrrCycle: "2026-09-21T17:00:00Z",
      domain: "conus",
      asOf: hour("2026-09-21T17:40:00Z"),
    },
  );
  assert.equal(payload.agreement_tier, "split");
  assert.equal(payload.divergence.present, true);
  assert.equal(
    payload.divergence.sentence,
    "The hourly model puts the rain near 1pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet.",
  );
  assert.equal(payload.divergence.sentence.includes("EAS"), false);
  assert.equal(payload.timing_window.soft_peak_local.includes("T15:00:00"), true);
});

test("hour labels stay on the hour", () => {
  const start = hour("2026-09-21T19:00:00Z");
  const end = hour("2026-09-21T22:00:00Z");
  assert.equal(hourLabel(start, zone), "2pm");
  assert.equal(rangePhrase(start, end, zone), "2 to 5pm");
  assert.equal(
    divergenceSentence({ hrrrPeak: hour("2026-09-21T20:00:00Z"), windowStart: start, windowEnd: end, timeZone: zone }),
    "The hourly model puts the rain near 3pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet.",
  );
});

test("parallel flips at the October 2026 cutover", () => {
  assert.equal(parallelAt(new Date("2026-10-14T11:59:00Z")), true);
  assert.equal(parallelAt(new Date("2026-10-14T12:00:00Z")), false);
});

test("stub is marked, parallel, and not a minute clock", () => {
  const stub = stubPayload();
  assert.equal(stub.stub, true);
  assert.equal(stub.parallel, true);
  assert.equal(stub.agreement_tier, "split");
  assert.match(stub.timing_window.start_local, /T\d{2}:00:00/);
  assert.match(stub.timing_window.end_local, /T\d{2}:00:00/);
  assert.equal(JSON.stringify(stub).toLowerCase().includes("eas"), false);
});
