// Time-zone math for the morning brief. Cron in the Agents SDK is UTC, but the
// brief has to land at a wall-clock hour in the device's own zone, so each run
// computes its own next occurrence instead of using a fixed cron expression.
// This is also what keeps the brief at 7am across a DST change.

interface ZonedParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function zonedParts(instant: number, timeZone: string): ZonedParts {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts: Record<string, number> = {};
  for (const part of formatter.formatToParts(new Date(instant))) {
    if (part.type !== "literal") parts[part.type] = Number(part.value);
  }
  return {
    year: parts.year,
    // `hour: "2-digit"` with hour12:false yields 24 for midnight in some ICU
    // versions; normalize so Date.UTC does not roll the day forward twice.
    month: parts.month,
    day: parts.day,
    hour: parts.hour % 24,
    minute: parts.minute,
    second: parts.second,
  };
}

/** Offset of `timeZone` from UTC at `instant`, in milliseconds. */
export function timeZoneOffsetMs(instant: number, timeZone: string): number {
  const p = zonedParts(instant, timeZone);
  const asUTC = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  // Formatted parts carry no milliseconds, so compare against a truncated instant
  // or every offset comes back off by the sub-second remainder.
  return asUTC - Math.floor(instant / 1000) * 1000;
}

/**
 * The UTC instant at which local wall-clock time in `timeZone` next reads
 * `hour:minute`, strictly after `from`.
 *
 * Offsets are resolved by iteration because the offset that applies depends on
 * the very instant being computed — one pass fixes the ordinary case, the second
 * fixes days where a DST transition moves the boundary.
 */
export function nextOccurrence(
  from: number,
  timeZone: string,
  hour: number,
  minute: number = 0,
): number {
  let candidateDay = zonedParts(from, timeZone);

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const wallClock = Date.UTC(
      candidateDay.year,
      candidateDay.month - 1,
      candidateDay.day,
      hour,
      minute,
      0,
    );

    let instant = wallClock - timeZoneOffsetMs(from, timeZone);
    // Re-resolve against the offset in force at the candidate instant itself.
    instant = wallClock - timeZoneOffsetMs(instant, timeZone);

    if (instant > from) return instant;

    // Already past today's slot — advance one local day and try again.
    const nextDay = new Date(
      Date.UTC(candidateDay.year, candidateDay.month - 1, candidateDay.day + 1),
    );
    candidateDay = {
      year: nextDay.getUTCFullYear(),
      month: nextDay.getUTCMonth() + 1,
      day: nextDay.getUTCDate(),
      hour,
      minute,
      second: 0,
    };
  }

  // Unreachable for valid zones; falling back to +24h is better than never firing.
  return from + 24 * 60 * 60 * 1000;
}

/** True for strings Intl accepts as an IANA zone. Registration rejects the rest. */
export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
}
