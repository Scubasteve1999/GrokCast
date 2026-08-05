// Server-side mirror of NWSService.fetchActiveAlerts + the NWSAlert severity
// computed properties. Kept deliberately in lockstep with
// DayCast/Shared/Services/NWSService.swift and Shared/Models/NWSModels.swift —
// if the classification changes there, change it here too, or the same storm
// produces two different notifications depending on which path fired.

const BASE_URL = "https://api.weather.gov";

/** NWS asks every client to identify itself; unidentified traffic gets blocked. */
export const NWS_USER_AGENT =
  "(DayCast/push-agent, mailto:stephenmoorecm1357@gmail.com)";

export interface NWSAlert {
  id: string;
  event: string;
  severity?: string;
  headline?: string;
  description?: string;
  instruction?: string;
  expires?: string;
  areaDesc?: string;
}

interface AlertsResponse {
  features?: Array<{
    id?: string;
    properties?: {
      event?: string;
      severity?: string;
      headline?: string;
      description?: string;
      instruction?: string;
      expires?: string;
      areaDesc?: string;
    };
  }>;
}

/** Mirrors NWSAlert.isSevereEvent — the gate for "is this push-worthy at all". */
export function isSevereEvent(alert: NWSAlert): boolean {
  const lower = alert.event.toLowerCase();
  return lower.includes("warning") || lower.includes("watch");
}

/** Mirrors NWSAlert.isWarning. */
export function isWarning(alert: NWSAlert): boolean {
  return alert.event.toLowerCase().includes("warning");
}

/** Mirrors NWSAlert.isLifeThreatening — drives the ⚠️ title prefix. */
export function isLifeThreatening(alert: NWSAlert): boolean {
  const lower = alert.event.toLowerCase();
  return (
    lower.includes("tornado warning") ||
    lower.includes("hurricane warning") ||
    lower.includes("extreme wind warning") ||
    lower.includes("storm surge warning") ||
    lower.includes("tsunami warning") ||
    lower.includes("flash flood emergency") ||
    (alert.severity ?? "").toLowerCase() === "extreme"
  );
}

/** Mirrors NWSAlert.expiresRelativeText. Returns undefined once expired. */
export function expiresRelativeText(
  alert: NWSAlert,
  now: number = Date.now(),
): string | undefined {
  if (!alert.expires) return undefined;
  const expires = Date.parse(alert.expires);
  if (Number.isNaN(expires) || expires <= now) return undefined;
  const interval = Math.floor((expires - now) / 1000);
  const hours = Math.floor(interval / 3600);
  const minutes = Math.floor((interval % 3600) / 60);
  return hours > 0 ? `Expires in ${hours}h ${minutes}m` : `Expires in ${minutes}m`;
}

export function parseAlerts(body: AlertsResponse): NWSAlert[] {
  return (body.features ?? []).flatMap((feature) => {
    const p = feature.properties;
    if (!p?.event) return [];
    return [
      {
        // Prefer the stable NWS feature id, same fallback shape as the Swift client.
        id: feature.id ?? `nws-${p.event}-${p.expires ?? "unknown"}`,
        event: p.event,
        severity: p.severity,
        headline: p.headline,
        description: p.description,
        instruction: p.instruction,
        expires: p.expires,
        areaDesc: p.areaDesc,
      },
    ];
  });
}

/**
 * Active alerts for a point. NWS returns 200 + `{ features: [] }` for quiet areas
 * *and* for non-US points, so an empty array is the normal, silent outcome —
 * matching hard rule 6 (NWS is strictly additive; failures stay quiet).
 */
export async function fetchActiveAlerts(
  latitude: number,
  longitude: number,
  fetchImpl: typeof fetch = fetch,
): Promise<NWSAlert[]> {
  const url = `${BASE_URL}/alerts/active?point=${latitude},${longitude}`;
  const response = await fetchImpl(url, {
    headers: { "User-Agent": NWS_USER_AGENT, Accept: "application/geo+json" },
  });
  if (!response.ok) {
    throw new Error(`NWS ${response.status}`);
  }
  return parseAlerts((await response.json()) as AlertsResponse);
}
