import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { valueAtIndex, readGrid } from "../src/grib.js";
import { gridIndex } from "../src/grid.js";
import {
  hrrrApcpRecord,
  parseIdx,
  refsLightPrecipRecord,
  upcomingForecastHours,
} from "../src/extract.js";

const hi = new Uint8Array(
  readFileSync(new URL("./fixtures/hi-eas-apcp0254.grib2", import.meta.url)),
);

test("decodes the light-precip agreement field to the eccodes point values", () => {
  const grid = readGrid(hi);
  assert.equal(grid.kind, "mercator");
  assert.equal(grid.nx, 321);
  assert.equal(grid.ny, 225);
  assert.equal(valueAtIndex(hi, 0), 0.84375);
  assert.equal(valueAtIndex(hi, 1), 0.890625);
  assert.ok(Math.abs(valueAtIndex(hi, 2) - 0.95117188) < 1e-6);
  assert.ok(Math.abs(valueAtIndex(hi, 7) - 1.13476562) < 1e-6);
  assert.equal(valueAtIndex(hi, 100), 1.71875);
  const hit = gridIndex(grid, 21.3069, -157.8583);
  assert.equal(hit.index, 46377);
  assert.equal(valueAtIndex(hi, hit.index), 0);
});

test("idx selects the 1-hour light-precip record and ignores longer stacks", () => {
  const text = [
    "1:0:d=2026092112:APCP:surface:0-1 hour acc fcst:prob >0.254:prob fcst 0/14:process=197",
    "2:461480:d=2026092112:APCP:surface:0-1 hour acc fcst:prob >6.35:prob fcst 0/14:process=197",
    "7:1062148:d=2026092112:APCP:surface:0-6 hour acc fcst:prob >0.254:prob fcst 0/14:process=197",
    "8:2000000:d=2026092112:APCP:surface:5-6 hour acc fcst:",
  ].join("\n");
  const records = parseIdx(text);
  const light = refsLightPrecipRecord(records, 1);
  assert.equal(light.offset, 0);
  assert.equal(light.end, 461479);
  assert.equal(refsLightPrecipRecord(records, 6), null);
  const hrrr = hrrrApcpRecord(
    parseIdx(
      [
        "84:100:d=2026092112:APCP:surface:0-6 hour acc fcst:",
        "90:200:d=2026092112:APCP:surface:5-6 hour acc fcst:",
        "91:900:d=2026092112:WEASD:surface:5-6 hour acc fcst:",
      ].join("\n"),
    ),
    6,
  );
  assert.equal(hrrr.offset, 200);
  assert.equal(hrrr.end, 899);
});

test("upcoming hours skip valid times that have already ended", () => {
  const cycle = { date: new Date("2026-09-21T12:00:00Z"), hour: 12 };
  const now = new Date("2026-09-21T19:10:00Z");
  const slots = upcomingForecastHours(cycle, now, 3, 60);
  assert.deepEqual(
    slots.map((slot) => slot.forecastHour),
    [7, 8, 9],
  );
  assert.equal(slots[0].valid.toISOString(), "2026-09-21T19:00:00.000Z");
});
