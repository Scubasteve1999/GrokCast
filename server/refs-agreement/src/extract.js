/**
 * Idx + byte-range extract from public AWS GRIB.
 * REFS light-precip agreement is the eas file's 1-hour APCP prob > 0.254 mm
 * (generating process 197). The app never sees the grid.
 */

import { valueAtIndex, readGrid } from "./grib.js";
import { gridIndex } from "./grid.js";

export const REFS_BUCKET = "https://noaa-rrfs-ops-pds.s3.amazonaws.com";
export const HRRR_BUCKET = "https://noaa-hrrr-bdp-pds.s3.amazonaws.com";

const REFS_CYCLES = [0, 6, 12, 18];

function pad(n, width = 2) {
  return String(n).padStart(width, "0");
}

function ymd(date) {
  return date.toISOString().slice(0, 10).replace(/-/g, "");
}

export function refsObject(cycle, domain, forecastHour) {
  const hh = pad(cycle.hour);
  const fff = pad(forecastHour);
  const key = `refs.${ymd(cycle.date)}/${hh}/ensprod/refs.t${hh}z.eas.f${fff}.${domain}.grib2`;
  return { key, url: `${REFS_BUCKET}/${key}` };
}

export function hrrrObject(cycle, domain, forecastHour) {
  const hh = pad(cycle.hour);
  const fff = pad(forecastHour);
  const region = domain === "ak" ? "alaska" : "conus";
  const suffix = domain === "ak" ? ".ak" : "";
  const key = `hrrr.${ymd(cycle.date)}/${region}/hrrr.t${hh}z.wrfsfcf${fff}${suffix}.grib2`;
  return { key, url: `${HRRR_BUCKET}/${key}` };
}

export function parseIdx(text) {
  const records = [];
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    const match = line.match(/^(\d+):(\d+):(.*)$/);
    if (!match) continue;
    records.push({
      index: Number(match[1]),
      offset: Number(match[2]),
      description: match[3],
    });
  }
  for (let i = 0; i < records.length; i += 1) {
    const next = records[i + 1];
    records[i].end = next ? next.offset - 1 : null;
  }
  return records;
}

/** 1-hour light-precip agreement record. Not the 3-hour or 6-hour stack. */
export function refsLightPrecipRecord(records, forecastHour) {
  const end = forecastHour;
  const start = forecastHour - 1;
  return (
    records.find((record) => {
      const text = record.description;
      if (!text.includes("APCP")) return false;
      if (!text.includes(`prob >0.254`)) return false;
      if (!text.includes("process=197")) return false;
      return text.includes(`${start}-${end} hour acc fcst`);
    }) ?? null
  );
}

/** Deterministic HRRR 1-hour precip amount. Not a probability record. */
export function hrrrApcpRecord(records, forecastHour) {
  const end = forecastHour;
  const start = forecastHour - 1;
  return (
    records.find((record) => {
      const text = record.description;
      if (!text.includes("APCP:surface:")) return false;
      if (text.includes("prob")) return false;
      return text.includes(`${start}-${end} hour acc fcst`);
    }) ?? null
  );
}

export async function fetchRange(fetchImpl, url, record) {
  const headers = {};
  if (record.end != null) headers.Range = `bytes=${record.offset}-${record.end}`;
  else headers.Range = `bytes=${record.offset}-`;
  const response = await fetchImpl(url, { headers });
  if (!response.ok && response.status !== 206) {
    throw new Error(`range_${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  return bytes;
}

export async function pointFromMessage(bytes, lat, lon) {
  const grid = readGrid(bytes);
  const hit = gridIndex(grid, lat, lon);
  if (!hit) return null;
  return valueAtIndex(bytes, hit.index);
}

async function getText(fetchImpl, url) {
  const response = await fetchImpl(url);
  if (!response.ok) return null;
  return response.text();
}

export function candidateRefsCycles(now, lookback = 4) {
  const cycles = [];
  const cursor = new Date(now.getTime());
  cursor.setUTCMinutes(0, 0, 0);
  const hour = cursor.getUTCHours();
  const slot = REFS_CYCLES.filter((cycle) => cycle <= hour).pop() ?? 18;
  if (slot === 18 && hour < 18) cursor.setUTCDate(cursor.getUTCDate() - 1);
  cursor.setUTCHours(slot, 0, 0, 0);
  for (let i = 0; i < lookback; i += 1) {
    cycles.push({ date: new Date(cursor.getTime()), hour: cursor.getUTCHours() });
    cursor.setUTCHours(cursor.getUTCHours() - 6);
  }
  return cycles;
}

export function candidateHrrrCycles(now, lookback = 4) {
  const cycles = [];
  const cursor = new Date(now.getTime());
  cursor.setUTCMinutes(0, 0, 0);
  for (let i = 0; i < lookback; i += 1) {
    cycles.push({ date: new Date(cursor.getTime()), hour: cursor.getUTCHours() });
    cursor.setUTCHours(cursor.getUTCHours() - 1);
  }
  return cycles;
}

export function cycleId(cycle) {
  return cycleStart(cycle).toISOString().replace(".000Z", "Z");
}

export function cycleStart(cycle) {
  const date = new Date(cycle.date.getTime());
  date.setUTCHours(cycle.hour, 0, 0, 0);
  return date;
}

/**
 * Forecast hours whose valid time has not ended yet, oldest first.
 * f01 of a 12z cycle is 13z — once that hour is over it is not a timing window.
 */
export function upcomingForecastHours(cycle, now, count, maxForecastHour) {
  const start = cycleStart(cycle).getTime();
  const hours = [];
  for (let forecastHour = 1; forecastHour <= maxForecastHour && hours.length < count; forecastHour += 1) {
    const valid = new Date(start + forecastHour * 3_600_000);
    if (valid.getTime() + 3_600_000 <= now.getTime()) continue;
    hours.push({ forecastHour, valid });
  }
  return hours;
}

async function mapPool(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const current = next;
      next += 1;
      results[current] = await fn(items[current], current);
    }
  }
  const workers = [];
  const count = Math.min(limit, items.length);
  for (let i = 0; i < count; i += 1) workers.push(worker());
  await Promise.all(workers);
  return results;
}

async function readHour(fetchImpl, object, recordPicker, forecastHour, lat, lon) {
  const idx = await getText(fetchImpl, `${object.url}.idx`);
  if (!idx) return null;
  const record = recordPicker(parseIdx(idx), forecastHour);
  if (!record) return null;
  const bytes = await fetchRange(fetchImpl, object.url, record);
  const value = await pointFromMessage(bytes, lat, lon);
  if (value == null || Number.isNaN(value)) return null;
  return value;
}

async function readSeries(fetchImpl, cycle, hours, readOne) {
  const values = await mapPool(hours, 4, async (slot) => {
    try {
      const value = await readOne(slot.forecastHour);
      return value == null ? null : { valid: slot.valid, value };
    } catch {
      return null;
    }
  });
  while (values.length && values[values.length - 1] == null) values.pop();
  if (values.length < 4 || values.some((value) => value == null)) return null;
  return values;
}

/**
 * Upcoming REFS eas percent. Trailing hours that are not published yet are dropped.
 * A hole in the middle fails closed — a missing hour is not "dry".
 */
export async function readRefsSeries(fetchImpl, cycle, domain, lat, lon, hours, now = new Date()) {
  const slots = upcomingForecastHours(cycle, now, hours, 60);
  const series = await readSeries(fetchImpl, cycle, slots, (forecastHour) =>
    readHour(
      fetchImpl,
      refsObject(cycle, domain, forecastHour),
      refsLightPrecipRecord,
      forecastHour,
      lat,
      lon,
    ),
  );
  if (!series) return null;
  return series.map((sample) => ({ valid: sample.valid, easPercent: sample.value }));
}

export async function readHrrrSeries(fetchImpl, cycle, domain, lat, lon, hours, now = new Date()) {
  if (domain !== "conus" && domain !== "ak") return null;
  const slots = upcomingForecastHours(cycle, now, hours, 18);
  const series = await readSeries(fetchImpl, cycle, slots, (forecastHour) =>
    readHour(
      fetchImpl,
      hrrrObject(cycle, domain, forecastHour),
      hrrrApcpRecord,
      forecastHour,
      lat,
      lon,
    ),
  );
  if (!series) return null;
  return series.map((sample) => ({ valid: sample.valid, apcpMillimeters: sample.value }));
}

export async function findRefsCycle(fetchImpl, domain, now, hours = 12) {
  for (const cycle of candidateRefsCycles(now)) {
    const slots = upcomingForecastHours(cycle, now, 1, 60);
    if (!slots.length) continue;
    const probe = refsObject(cycle, domain, slots[0].forecastHour);
    const idx = await getText(fetchImpl, `${probe.url}.idx`);
    if (idx && idx.includes("prob >0.254") && upcomingForecastHours(cycle, now, hours, 60).length >= 4) {
      return cycle;
    }
  }
  return null;
}

export async function findHrrrCycle(fetchImpl, domain, now) {
  if (domain !== "conus" && domain !== "ak") return null;
  for (const cycle of candidateHrrrCycles(now)) {
    const probe = hrrrObject(cycle, domain, 1);
    const idx = await getText(fetchImpl, `${probe.url}.idx`);
    if (idx && idx.includes("APCP:surface:")) return cycle;
  }
  return null;
}
