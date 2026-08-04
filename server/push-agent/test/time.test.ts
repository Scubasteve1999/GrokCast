import assert from "node:assert/strict";
import { test } from "node:test";

import { isValidTimeZone, nextOccurrence, timeZoneOffsetMs } from "../src/time.ts";

/** Renders an instant as wall-clock time in a zone, for readable assertions. */
function wallClock(instant: number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  })
    .format(new Date(instant))
    .replace(", ", " ");
}

test("timeZoneOffsetMs reports standard and daylight offsets", () => {
  const january = Date.parse("2026-01-15T12:00:00Z");
  const july = Date.parse("2026-07-15T12:00:00Z");

  assert.equal(timeZoneOffsetMs(january, "America/Chicago"), -6 * 3600_000);
  assert.equal(timeZoneOffsetMs(july, "America/Chicago"), -5 * 3600_000);
  assert.equal(timeZoneOffsetMs(july, "UTC"), 0);
});

test("timeZoneOffsetMs ignores sub-second remainders", () => {
  const instant = Date.parse("2026-07-15T12:00:00Z") + 750;
  assert.equal(timeZoneOffsetMs(instant, "America/Chicago"), -5 * 3600_000);
});

test("nextOccurrence finds today's slot when it is still ahead", () => {
  // 05:00 in Chicago on Aug 3.
  const from = Date.parse("2026-08-03T10:00:00Z");
  const next = nextOccurrence(from, "America/Chicago", 7);

  assert.equal(wallClock(next, "America/Chicago"), "2026-08-03 07:00");
  assert.ok(next > from);
});

test("nextOccurrence rolls to tomorrow once today's slot has passed", () => {
  // 09:00 in Chicago — 07:00 is gone.
  const from = Date.parse("2026-08-03T14:00:00Z");
  const next = nextOccurrence(from, "America/Chicago", 7);

  assert.equal(wallClock(next, "America/Chicago"), "2026-08-04 07:00");
});

test("nextOccurrence is strictly after `from`, never equal to it", () => {
  const exactly7am = Date.parse("2026-08-03T12:00:00Z"); // 07:00 Chicago
  const next = nextOccurrence(exactly7am, "America/Chicago", 7);

  assert.ok(next > exactly7am);
  assert.equal(wallClock(next, "America/Chicago"), "2026-08-04 07:00");
});

test("the brief stays at 07:00 local across the spring-forward transition", () => {
  // US DST begins 2026-03-08. Ask on the 7th for the next 07:00.
  const from = Date.parse("2026-03-07T20:00:00Z");
  const next = nextOccurrence(from, "America/Chicago", 7);

  assert.equal(wallClock(next, "America/Chicago"), "2026-03-08 07:00");
  // Proof this is real zone math and not a fixed +24h: consecutive 07:00 briefs
  // across the spring-forward boundary are 23 hours apart in absolute time.
  const previous = nextOccurrence(Date.parse("2026-03-06T20:00:00Z"), "America/Chicago", 7);
  assert.equal(wallClock(previous, "America/Chicago"), "2026-03-07 07:00");
  assert.equal(next - previous, 23 * 3600_000);
});

test("the brief stays at 07:00 local across the fall-back transition", () => {
  // US DST ends 2026-11-01.
  const from = Date.parse("2026-10-31T20:00:00Z");
  const next = nextOccurrence(from, "America/Chicago", 7);

  assert.equal(wallClock(next, "America/Chicago"), "2026-11-01 07:00");
});

test("nextOccurrence handles half-hour and cross-date-line zones", () => {
  const from = Date.parse("2026-08-03T00:00:00Z");

  // 05:30 local in Kolkata (UTC+5:30) — today's 07:00 is still ahead.
  assert.equal(
    wallClock(nextOccurrence(from, "Asia/Kolkata", 7), "Asia/Kolkata"),
    "2026-08-03 07:00",
  );
  // 12:00 local in Auckland (UTC+12) — the same instant is already past 07:00 there,
  // so the brief correctly lands tomorrow.
  assert.equal(
    wallClock(nextOccurrence(from, "Pacific/Auckland", 7), "Pacific/Auckland"),
    "2026-08-04 07:00",
  );
});

test("nextOccurrence handles a midnight brief hour without rolling twice", () => {
  const from = Date.parse("2026-08-03T10:00:00Z"); // 05:00 Chicago
  const next = nextOccurrence(from, "America/Chicago", 0);

  assert.equal(wallClock(next, "America/Chicago"), "2026-08-04 00:00");
});

test("isValidTimeZone accepts IANA ids and rejects junk", () => {
  assert.equal(isValidTimeZone("America/Chicago"), true);
  assert.equal(isValidTimeZone("UTC"), true);
  assert.equal(isValidTimeZone("Mars/Olympus"), false);
  assert.equal(isValidTimeZone(""), false);
});
