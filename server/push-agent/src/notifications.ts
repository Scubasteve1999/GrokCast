// APNs payload builders. The copy here mirrors AlertNotificationService and
// MorningBriefNotificationService so a server-delivered push is indistinguishable
// from the locally-scheduled one — same titles, same truncation, same deep links,
// same thread ids (so they coalesce in Notification Center instead of stacking).

import type { NWSAlert } from "./nws.ts";
import { expiresRelativeText, isLifeThreatening } from "./nws.ts";

// Mirrors GrokCastDeepLinks.
const DEEP_LINK_TODAY = "grokcast://today";
const DEEP_LINK_ALERTS = "grokcast://alerts";

// Mirrors the categoryIdentifier constants the app registers.
const CATEGORY_SEVERE = "GROKCAST_SEVERE_ALERT";
const CATEGORY_CRITICAL = "GROKCAST_CRITICAL_ALERT";
const CATEGORY_MORNING_BRIEF = "GROKCAST_MORNING_BRIEF";

export interface APNsAlertPayload {
  aps: {
    alert: { title: string; subtitle?: string; body: string };
    sound?: string;
    category: string;
    "thread-id": string;
    "interruption-level"?: "passive" | "active" | "time-sensitive" | "critical";
    "mutable-content"?: number;
  };
  deepLink: string;
  alertId?: string;
  severity?: string;
}

/** Mirrors AlertNotificationService.buildSubtitle. */
export function buildAlertSubtitle(alert: NWSAlert, now: number = Date.now()): string {
  const parts: string[] = [];
  if (alert.areaDesc && alert.areaDesc.length > 0) {
    parts.push(alert.areaDesc.slice(0, 80));
  }
  const expiry = expiresRelativeText(alert, now);
  if (expiry) parts.push(expiry);
  return parts.join(" · ");
}

/** Mirrors AlertNotificationService.buildBody, including the 300-char cap. */
export function buildAlertBody(alert: NWSAlert): string {
  if (alert.instruction && alert.instruction.length > 0) {
    return alert.instruction.slice(0, 300);
  }
  if (alert.headline && alert.headline.length > 0) {
    return alert.headline.slice(0, 300);
  }
  if (alert.description && alert.description.length > 0) {
    return alert.description.slice(0, 300);
  }
  return "Tap to view alert details in DayCast.";
}

export function buildAlertPayload(
  alert: NWSAlert,
  options: { soundsEnabled: boolean; now?: number },
): APNsAlertPayload {
  const now = options.now ?? Date.now();
  const lifeThreatening = isLifeThreatening(alert);

  const payload: APNsAlertPayload = {
    aps: {
      alert: {
        // The ⚠️ prefix is the app's own marker for life-threatening events.
        title: lifeThreatening ? `⚠️ ${alert.event}` : alert.event,
        subtitle: buildAlertSubtitle(alert, now) || undefined,
        body: buildAlertBody(alert),
      },
      category: lifeThreatening ? CATEGORY_CRITICAL : CATEGORY_SEVERE,
      "thread-id": "grokcast-severe-alerts",
      // The app sets .timeSensitive on every severe alert regardless of tier.
      // Without the Time Sensitive Notifications capability iOS quietly downgrades
      // this to .active, which is the same behaviour the local path already gets.
      "interruption-level": "time-sensitive",
    },
    deepLink: DEEP_LINK_ALERTS,
    alertId: alert.id,
  };

  // Sound is a device-local preference (GrokCastNotificationSounds), so the device
  // reports it at registration — the server has no other way to know.
  if (options.soundsEnabled) payload.aps.sound = "default";
  if (alert.severity) payload.severity = alert.severity;

  return payload;
}

/** Mirrors MorningBriefNotificationService.greeting. */
export function morningBriefGreeting(hour: number, location?: string): string {
  const place = location ?? "your area";
  if (hour >= 7 && hour <= 9) return `Good morning — ${place}`;
  if (hour >= 10 && hour <= 11) return `Morning update — ${place}`;
  return `Weather brief — ${place}`;
}

/** Mirrors MorningBriefNotificationService.subtitle. */
export function morningBriefSubtitle(temperature?: string, condition?: string): string {
  if (temperature && condition) return `${temperature} · ${condition}`;
  return temperature ?? condition ?? "";
}

export function buildMorningBriefPayload(options: {
  hour: number;
  locationName?: string;
  temperature?: string;
  condition?: string;
  briefBody?: string;
  soundsEnabled: boolean;
}): APNsAlertPayload {
  const trimmed = (options.briefBody ?? "").trim();
  const payload: APNsAlertPayload = {
    aps: {
      alert: {
        title: morningBriefGreeting(options.hour, options.locationName),
        subtitle:
          morningBriefSubtitle(options.temperature, options.condition) || undefined,
        body:
          trimmed.length === 0
            ? "Open DayCast for today's weather and AI take."
            : trimmed.slice(0, 220),
      },
      category: CATEGORY_MORNING_BRIEF,
      "thread-id": "grokcast-morning-brief",
    },
    deepLink: DEEP_LINK_TODAY,
  };
  if (options.soundsEnabled) payload.aps.sound = "default";
  return payload;
}

/**
 * Silent push. `content-available: 1` with no alert/sound/badge is what
 * PushNotificationService.didReceiveRemoteNotification already routes into
 * WeatherStore.performBackgroundRefresh.
 */
export function buildSilentRefreshPayload(): { aps: { "content-available": 1 } } {
  return { aps: { "content-available": 1 } };
}
