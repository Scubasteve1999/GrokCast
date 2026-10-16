/**
 * Grok output verifier — asks TypeSafe (Jev) narrow yes/no questions about a
 * finished Grok reply, so the app can swap in its deterministic copy.
 *
 * Questions and thresholds come from the October 2026 experiments
 * (docs/briefs/2026-10-16-typesafe-verifier.md). Keep the wording frozen: the
 * thresholds were measured against exactly this text. The verifier only ever
 * blocks; it never overrides the app's own keyword screen.
 *
 * Numbers stay in code: the pin's precipitation chance is bucketed into words
 * here because Jev is documented as weak at numeric comparison.
 */

import { RequestPolicyError } from "./request-policy.js";

const TYPESAFE_URL = "https://api.typesafe.ai/v1/systemone";
/** Pinned, not `jev-latest`: an alias move would silently shift calibrated thresholds. */
const DEFAULT_MODEL = "jev-1.14.0";

/** Safety errs toward blocking: jev-1.13 put two subtle harmful cases at exactly 0.50. */
export const HARMFUL_THRESHOLD = 0.3;
export const UNSUPPORTED_THRESHOLD = 0.5;

const MAX_TEXT = 4000;
const MAX_BODY = 16 * 1024;
const MAX_FIELD = 120;

const HARMFUL_QUESTION = {
  type: "noul",
  instructions:
    "Does `text` advise the reader to disregard an official weather warning, watch, alert, or evacuation order, or to skip a protective action (sheltering, taking cover, evacuating, avoiding flooded roads, going indoors from lightning) during hazardous weather?",
  criteria: {
    true: "Discourages safe behavior: dismisses warnings as overblown or fake, or encourages staying outdoors, driving into floodwater, or not evacuating/sheltering when the hazard calls for it.",
    false:
      "Encourages safety, gives accurate guidance about WHERE or WHEN to shelter (e.g., 'don't shelter under an overpass'), or is ordinary weather information.",
  },
};

const UNSUPPORTED_QUESTION = {
  type: "noul",
  instructions:
    "Does `text` claim something about precipitation at `pin_forecast.location` (right now or in the next few hours) that conflicts with `pin_forecast`?",
  criteria: {
    true: "The text says or implies rain, drizzle, showers, or storms are falling or about to fall at the location when the forecast condition is not wet and the chance is slight or none; OR it says the location is dry when the forecast condition is wet and the chance is likely.",
    false:
      "The text's statements about precipitation at the location agree with the forecast, are hedged to match a slight chance, or describe precipitation somewhere else, or deny precipitation that the forecast also does not expect.",
  },
};

export function chanceWords(percent) {
  if (percent === 0) return "0% (none)";
  if (percent < 30) return `${percent}% (slight chance)`;
  if (percent < 60) return `${percent}% (chance)`;
  return `${percent}% (likely)`;
}

function reject(message) {
  throw new RequestPolicyError(message);
}

function shortString(value, name) {
  if (typeof value !== "string" || !value.trim() || value.length > MAX_FIELD) reject(`Invalid ${name}.`);
  return value.trim();
}

/** Validates the app's body and builds the TypeSafe request. Throws RequestPolicyError. */
export async function verifyRequest(request) {
  if (new URL(request.url).search) reject("Query parameters are not supported.");
  if ((request.headers.get("Content-Type") ?? "").split(";")[0].trim().toLowerCase() !== "application/json") {
    throw new RequestPolicyError("Content-Type must be application/json.", 415);
  }
  if (Number(request.headers.get("Content-Length")) > MAX_BODY) throw new RequestPolicyError("Request is too large.", 413);
  const raw = await request.text();
  if (raw.length > MAX_BODY) throw new RequestPolicyError("Request is too large.", 413);
  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    reject("Invalid JSON.");
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) reject("Invalid JSON.");
  if (Object.keys(body).some((key) => !["kind", "text", "pin"].includes(key))) reject("Unsupported request fields.");
  if (typeof body.text !== "string" || !body.text.trim() || body.text.length > MAX_TEXT) reject("Invalid text.");

  if (body.kind === "brief") {
    if (body.pin !== undefined) reject("Unsupported request fields.");
    return { state: { text: body.text }, questions: { harmful_advice: HARMFUL_QUESTION } };
  }
  if (body.kind !== "radar") reject("Unsupported verify kind.");

  const pin = body.pin;
  if (pin === null || typeof pin !== "object" || Array.isArray(pin)) reject("Radar verify needs a pin.");
  if (Object.keys(pin).some((key) => !["location", "condition", "precipitation_chance"].includes(key))) {
    reject("Unsupported pin fields.");
  }
  const chance = pin.precipitation_chance;
  if (!Number.isInteger(chance) || chance < 0 || chance > 100) reject("Invalid precipitation chance.");
  return {
    state: {
      pin_forecast: {
        location: shortString(pin.location, "location"),
        condition: shortString(pin.condition, "condition"),
        chance_of_precipitation: chanceWords(chance),
      },
      radar_layer_name: "Rain",
      text: body.text,
    },
    questions: { harmful_advice: HARMFUL_QUESTION, unsupported_precipitation: UNSUPPORTED_QUESTION },
  };
}

/** Policy lives here, not in the app, so a threshold change needs no App Store release. */
export function verdictFrom(answers) {
  const scores = {};
  const reasons = [];
  const harmful = answers?.harmful_advice?.noul;
  if (typeof harmful !== "number") throw new Error("TypeSafe response is missing harmful_advice");
  scores.harmful_advice = harmful;
  if (harmful >= HARMFUL_THRESHOLD) reasons.push("harmful_advice");
  if (answers.unsupported_precipitation !== undefined) {
    const unsupported = answers.unsupported_precipitation.noul;
    if (typeof unsupported !== "number") throw new Error("TypeSafe response is missing unsupported_precipitation");
    scores.unsupported_precipitation = unsupported;
    if (unsupported >= UNSUPPORTED_THRESHOLD) reasons.push("unsupported_precipitation");
  }
  return { verdict: reasons.length ? "block" : "pass", reasons, scores };
}

/** Returns `{ status, body }`. Upstream trouble is a 502 the app treats as "no verdict". */
export async function runVerify(prepared, env, { fetchImpl = fetch } = {}) {
  let upstream;
  try {
    upstream = await fetchImpl(TYPESAFE_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${env.TYPESAFE_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: env.TYPESAFE_MODEL || DEFAULT_MODEL, ...prepared }),
      // The app is waiting on a finished reply; a slow verdict is worse than none.
      signal: AbortSignal.timeout(4_000),
    });
  } catch {
    return { status: 502, upstreamStatus: null };
  }
  if (!upstream.ok) return { status: 502, upstreamStatus: upstream.status };
  try {
    const result = await upstream.json();
    return { status: 200, body: { ...verdictFrom(result.answers), model: result.model } };
  } catch {
    return { status: 502, upstreamStatus: upstream.status };
  }
}
