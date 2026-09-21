/**
 * REFS timing-confidence contract.
 * A window is always at least one model hour. A soft peak is never emitted alone.
 * Thresholds are a thin MVP, not a calibrated probability product.
 */

export const WET_EAS_PERCENT = 30;
export const LOCKED_MAX_HOURS = 2;
export const LOCKED_MIN_PEAK = 60;
export const LIKELY_MAX_HOURS = 4;
export const LIKELY_MIN_PEAK = 40;
export const HRRR_WET_MM = 0.254;
export const LIGHT_PRECIP_MM = 0.254;
export const CUTOVER_UTC = Date.parse("2026-10-14T12:00:00Z");

export function floorHour(date) {
  return new Date(Math.floor(date.getTime() / 3_600_000) * 3_600_000);
}

export function parallelAt(asOf) {
  return asOf.getTime() < CUTOVER_UTC;
}

function parts(date, timeZone) {
  const format = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
    timeZoneName: "longOffset",
  });
  const map = {};
  for (const part of format.formatToParts(date)) map[part.type] = part.value;
  return map;
}

export function formatLocal(date, timeZone) {
  const map = parts(date, timeZone);
  const offset = (map.timeZoneName ?? "GMT").replace("GMT", "") || "+00:00";
  const normalized = offset === "" ? "+00:00" : offset;
  return `${map.year}-${map.month}-${map.day}T${map.hour}:${map.minute}:${map.second}${normalized}`;
}

export function hourLabel(date, timeZone) {
  const hour = Number(parts(date, timeZone).hour);
  const suffix = hour >= 12 ? "pm" : "am";
  const clock = hour % 12 === 0 ? 12 : hour % 12;
  return `${clock}${suffix}`;
}

export function rangePhrase(start, end, timeZone) {
  const startHour = Number(parts(start, timeZone).hour);
  const endHour = Number(parts(end, timeZone).hour);
  const startSuffix = startHour >= 12 ? "pm" : "am";
  const endSuffix = endHour >= 12 ? "pm" : "am";
  const startClock = startHour % 12 === 0 ? 12 : startHour % 12;
  const endClock = endHour % 12 === 0 ? 12 : endHour % 12;
  if (startSuffix === endSuffix) return `${startClock} to ${endClock}${endSuffix}`;
  return `${startClock}${startSuffix} to ${endClock}${endSuffix}`;
}

export function divergenceSentence({ hrrrPeak, windowStart, windowEnd, timeZone }) {
  const near = hourLabel(hrrrPeak, timeZone);
  if (!windowStart || !windowEnd) {
    return `The hourly model puts the rain near ${near}; the ensemble still doesn't share that hour — the timing isn't locked yet.`;
  }
  const range = rangePhrase(windowStart, windowEnd, timeZone);
  return `The hourly model puts the rain near ${near}; the ensemble still says anywhere from ${range} — the timing isn't locked yet.`;
}

function wetHours(samples) {
  return samples
    .map((sample) => ({ ...sample, valid: floorHour(sample.valid) }))
    .filter((sample) => sample.easPercent >= WET_EAS_PERCENT)
    .sort((a, b) => a.valid - b.valid);
}

function hrrrPeak(samples) {
  const wet = samples
    .map((sample) => ({ ...sample, valid: floorHour(sample.valid) }))
    .filter((sample) => sample.apcpMillimeters >= HRRR_WET_MM)
    .sort((a, b) => b.apcpMillimeters - a.apcpMillimeters || a.valid - b.valid);
  return wet[0] ?? null;
}

/**
 * @param {{ valid: Date, easPercent: number }[]} refsHours
 * @param {{ valid: Date, apcpMillimeters: number }[] | null} hrrrHours
 * @param {string} timeZone
 * @param {{ refsCycle: string, hrrrCycle?: string | null, domain: string, asOf?: Date }} meta
 */
export function classify(refsHours, hrrrHours, timeZone, meta) {
  const asOf = meta.asOf ?? new Date();
  const lookedAtHrrr = Array.isArray(hrrrHours);
  const labels = lookedAtHrrr ? ["REFS", "HRRR"] : ["REFS"];
  const wet = wetHours(refsHours);
  const peak = hrrrPeak(hrrrHours ?? []);
  const sources = {
    refs_cycle: meta.refsCycle,
    domain: meta.domain,
    labels,
  };
  if (meta.hrrrCycle) sources.hrrr_cycle = meta.hrrrCycle;

  const base = {
    sources,
    as_of: asOf.toISOString(),
    parallel: parallelAt(asOf),
  };

  if (wet.length === 0) {
    if (peak) {
      return {
        ...base,
        agreement_tier: "split",
        divergence: {
          present: true,
          hrrr_peak_local: formatLocal(peak.valid, timeZone),
          sentence: divergenceSentence({
            hrrrPeak: peak.valid,
            windowStart: null,
            windowEnd: null,
            timeZone,
          }),
        },
      };
    }
    return { ...base, agreement_tier: "dry_consensus" };
  }

  const start = wet[0].valid;
  const last = wet[wet.length - 1].valid;
  const end = new Date(last.getTime() + 3_600_000);
  const widthHours = Math.max(1, Math.round((end.getTime() - start.getTime()) / 3_600_000));
  const soft = wet.reduce((best, sample) =>
    sample.easPercent > best.easPercent ? sample : best,
  );
  const softInside = soft.valid >= start && soft.valid < end;
  const timing = {
    start_local: formatLocal(start, timeZone),
    end_local: formatLocal(end, timeZone),
    width_hours: widthHours,
  };
  if (softInside) timing.soft_peak_local = formatLocal(soft.valid, timeZone);

  const peakOutside =
    peak && (peak.valid < start || peak.valid >= end);
  let tier;
  if (peakOutside) tier = "split";
  else if (widthHours <= LOCKED_MAX_HOURS && soft.easPercent >= LOCKED_MIN_PEAK) tier = "locked";
  else if (widthHours <= LIKELY_MAX_HOURS && soft.easPercent >= LIKELY_MIN_PEAK) tier = "likely_window";
  else tier = "wide_window";

  const payload = {
    ...base,
    agreement_tier: tier,
    timing_window: timing,
  };
  if (peakOutside) {
    payload.divergence = {
      present: true,
      hrrr_peak_local: formatLocal(peak.valid, timeZone),
      sentence: divergenceSentence({
        hrrrPeak: peak.valid,
        windowStart: start,
        windowEnd: end,
        timeZone,
      }),
    };
  }
  return payload;
}

/**
 * Documented sample for `?stub=1` and QA. Not a live grid extract.
 * HRRR peak is 1pm CDT, outside the 2–5pm REFS window, so the tier is split.
 * parallel stays true through the October 2026 cutover.
 */
export function stubPayload(now = new Date("2026-09-21T18:00:00Z")) {
  const zone = "America/Chicago";
  const hour = (h) => new Date(`2026-09-21T${String(h).padStart(2, "0")}:00:00Z`);
  const refs = [19, 20, 21].map((h) => ({ valid: hour(h), easPercent: h === 20 ? 55 : 40 }));
  const hrrr = [{ valid: hour(18), apcpMillimeters: 1.2 }];
  const payload = classify(refs, hrrr, zone, {
    refsCycle: "2026-09-21T12:00:00Z",
    hrrrCycle: "2026-09-21T17:00:00Z",
    domain: "conus",
    asOf: now,
  });
  payload.stub = true;
  payload.parallel = true;
  return payload;
}
