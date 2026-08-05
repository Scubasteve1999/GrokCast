import { Agent } from "agents";

import type { APNsCredentials, APNsEnvironment, APNsResult } from "./apns.ts";
import { sendAPNs } from "./apns.ts";
import type { NWSAlert } from "./nws.ts";
import { fetchActiveAlerts, isSevereEvent } from "./nws.ts";
import type { TemperatureUnit } from "./openmeteo.ts";
import { fetchCurrentConditions } from "./openmeteo.ts";
import {
  buildAlertPayload,
  buildMorningBriefPayload,
  buildSilentRefreshPayload,
} from "./notifications.ts";
import { nextOccurrence } from "./time.ts";

/**
 * Outcome of one delivery attempt. `attempted: false` means the push never left
 * the worker — no token, or the kill switch is on — which is a different thing
 * from APNs rejecting it, and callers loop differently on the two.
 */
export type DeliveryResult =
  | (APNsResult & { attempted: true })
  | { ok: false; attempted: false; reason: string; tokenIsDead: false };

export interface Env {
  DEVICE_AGENT: DurableObjectNamespace<DeviceAgent>;
  APNS_KEY_P8: string;
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_BUNDLE_ID: string;
  APNS_DEFAULT_ENVIRONMENT: string;
  ALERT_POLL_SECONDS: string;
  DISABLED: string;
  PUSH_SECRET: string;
  ADMIN_SECRET: string;
}

export interface RegisterInput {
  apnsToken: string;
  environment?: APNsEnvironment;
  latitude: number;
  longitude: number;
  locationName?: string;
  timeZone: string;
  alertsEnabled: boolean;
  morningBriefEnabled: boolean;
  morningBriefHour: number;
  soundsEnabled: boolean;
  temperatureUnit: TemperatureUnit;
}

export interface DeviceState {
  apnsToken: string | null;
  environment: APNsEnvironment;
  latitude: number | null;
  longitude: number | null;
  locationName: string | null;
  timeZone: string;
  alertsEnabled: boolean;
  morningBriefEnabled: boolean;
  morningBriefHour: number;
  soundsEnabled: boolean;
  temperatureUnit: TemperatureUnit;
  /**
   * Alert ids already pushed. Mirrors AlertHistoryStore on the device so the two
   * paths don't double-notify. Capped — NWS ids are long and state has a budget.
   */
  notifiedAlertIds: string[];
  /**
   * Mirrors AlertHistoryStore.hasCompletedInitialAlertSync: the first poll records
   * what is already active without pushing, so enrolling mid-storm doesn't fire a
   * burst of notifications for alerts the user has already seen.
   */
  initialSyncDone: boolean;
  lastPollAt: number | null;
  lastPushAt: number | null;
  lastError: string | null;
}

const MAX_REMEMBERED_ALERT_IDS = 200;

/** Alert pushes are pointless once the event is over; 2h is past most warnings. */
const ALERT_EXPIRATION_SECONDS = 2 * 60 * 60;

export class DeviceAgent extends Agent<Env, DeviceState> {
  initialState: DeviceState = {
    apnsToken: null,
    environment: "production",
    latitude: null,
    longitude: null,
    locationName: null,
    timeZone: "UTC",
    alertsEnabled: false,
    morningBriefEnabled: false,
    morningBriefHour: 7,
    soundsEnabled: true,
    temperatureUnit: "fahrenheit",
    notifiedAlertIds: [],
    initialSyncDone: false,
    lastPollAt: null,
    lastPushAt: null,
    lastError: null,
  };

  // MARK: - Registration

  /**
   * Idempotent: the app calls this on every launch and whenever the APNs token,
   * location, or notification preferences change. Schedules are reconciled to
   * match the incoming preferences rather than blindly re-added.
   */
  async register(input: RegisterInput): Promise<{ ok: true }> {
    const previousLocation = `${this.state.latitude},${this.state.longitude}`;
    const nextLocation = `${input.latitude},${input.longitude}`;

    this.setState({
      ...this.state,
      apnsToken: input.apnsToken,
      environment:
        input.environment ??
        (this.env.APNS_DEFAULT_ENVIRONMENT === "sandbox" ? "sandbox" : "production"),
      latitude: input.latitude,
      longitude: input.longitude,
      locationName: input.locationName ?? null,
      timeZone: input.timeZone,
      alertsEnabled: input.alertsEnabled,
      morningBriefEnabled: input.morningBriefEnabled,
      morningBriefHour: input.morningBriefHour,
      soundsEnabled: input.soundsEnabled,
      temperatureUnit: input.temperatureUnit,
      // Moving to a new place means a new set of active alerts. Re-baseline so the
      // user isn't pushed every warning already running at their destination.
      initialSyncDone:
        previousLocation === nextLocation ? this.state.initialSyncDone : false,
      notifiedAlertIds:
        previousLocation === nextLocation ? this.state.notifiedAlertIds : [],
      lastError: null,
    });

    await this.reconcileSchedules();
    return { ok: true };
  }

  /** Called when the user revokes notification permission or signs out of pushes. */
  async unregister(): Promise<{ ok: true }> {
    await this.cancelAll();
    this.setState({ ...this.initialState });
    return { ok: true };
  }

  /** Diagnostic view. Never returns the APNs token itself. */
  async status(): Promise<Record<string, unknown>> {
    const schedules = await this.listSchedules();
    return {
      registered: this.state.apnsToken !== null,
      environment: this.state.environment,
      latitude: this.state.latitude,
      longitude: this.state.longitude,
      timeZone: this.state.timeZone,
      alertsEnabled: this.state.alertsEnabled,
      morningBriefEnabled: this.state.morningBriefEnabled,
      morningBriefHour: this.state.morningBriefHour,
      initialSyncDone: this.state.initialSyncDone,
      trackedAlertIds: this.state.notifiedAlertIds.length,
      lastPollAt: this.state.lastPollAt,
      lastPushAt: this.state.lastPushAt,
      lastError: this.state.lastError,
      schedules: schedules.map((s) => ({ id: s.id, callback: s.callback, time: s.time })),
    };
  }

  // MARK: - Scheduling

  private async cancelAll(): Promise<void> {
    for (const schedule of await this.listSchedules()) {
      await this.cancelSchedule(schedule.id);
    }
  }

  private async schedulesFor(callback: string) {
    return (await this.listSchedules()).filter((s) => s.callback === callback);
  }

  private async reconcileSchedules(): Promise<void> {
    const alertSchedules = await this.schedulesFor("pollAlerts");
    if (this.state.alertsEnabled && this.state.apnsToken) {
      if (alertSchedules.length === 0) {
        const seconds = Number(this.env.ALERT_POLL_SECONDS) || 300;
        await this.scheduleEvery(seconds, "pollAlerts");
        // Poll straight away so a device that just enabled alerts gets its
        // baseline recorded now rather than one interval from now.
        await this.pollAlerts();
      }
    } else {
      for (const schedule of alertSchedules) await this.cancelSchedule(schedule.id);
    }

    // The brief always reschedules itself, so the only thing to reconcile here is
    // whether a pending one exists and whether it still points at the right hour.
    for (const schedule of await this.schedulesFor("sendMorningBrief")) {
      await this.cancelSchedule(schedule.id);
    }
    if (this.state.morningBriefEnabled && this.state.apnsToken) {
      await this.scheduleNextMorningBrief();
    }
  }

  private async scheduleNextMorningBrief(): Promise<void> {
    const when = nextOccurrence(Date.now(), this.state.timeZone, this.state.morningBriefHour);
    await this.schedule(new Date(when), "sendMorningBrief");
  }

  // MARK: - Scheduled callbacks

  /**
   * Mirrors AlertNotificationService.notifyIfNeeded, but running server-side so it
   * fires with the app closed. NWS failures stay silent per hard rule 6 — they are
   * recorded in state for diagnostics and nothing is surfaced to the user.
   */
  async pollAlerts(): Promise<void> {
    const { latitude, longitude, apnsToken } = this.state;
    if (latitude === null || longitude === null || !apnsToken) return;
    if (this.env.DISABLED === "1") return;

    let alerts: NWSAlert[];
    try {
      alerts = await fetchActiveAlerts(latitude, longitude);
    } catch (error) {
      this.setState({
        ...this.state,
        lastPollAt: Date.now(),
        lastError: error instanceof Error ? error.message : String(error),
      });
      return;
    }

    const severe = alerts.filter(isSevereEvent);

    if (!this.state.initialSyncDone) {
      this.setState({
        ...this.state,
        notifiedAlertIds: capIds(severe.map((a) => a.id)),
        initialSyncDone: true,
        lastPollAt: Date.now(),
        lastError: null,
      });
      return;
    }

    const alreadyNotified = new Set(this.state.notifiedAlertIds);
    const fresh = severe.filter((alert) => !alreadyNotified.has(alert.id));

    if (fresh.length === 0) {
      this.setState({ ...this.state, lastPollAt: Date.now(), lastError: null });
      return;
    }

    const delivered: string[] = [];
    for (const alert of fresh) {
      const result = await this.deliver({
        payload: buildAlertPayload(alert, { soundsEnabled: this.state.soundsEnabled }),
        pushType: "alert",
        expiration: Math.floor(Date.now() / 1000) + ALERT_EXPIRATION_SECONDS,
        // One notification per NWS alert, even if an update re-sends it.
        collapseId: alert.id.slice(-64),
      });
      if (result.ok) delivered.push(alert.id);
      // A dead token or an un-attempted send fails identically for every remaining
      // alert, so stop rather than hammering APNs once per active warning.
      if (result.tokenIsDead || !result.attempted) break;
    }

    this.setState({
      ...this.state,
      // Remember every id seen this round, not just the delivered ones — a token
      // that has gone dead would otherwise re-queue the same alerts forever.
      notifiedAlertIds: capIds([...this.state.notifiedAlertIds, ...severe.map((a) => a.id)]),
      lastPollAt: Date.now(),
      lastPushAt: delivered.length > 0 ? Date.now() : this.state.lastPushAt,
      lastError: null,
    });
  }

  /** Server-side counterpart to MorningBriefNotificationService. */
  async sendMorningBrief(): Promise<void> {
    // Reschedule first: an APNs failure must not silently end the daily brief.
    if (this.state.morningBriefEnabled && this.state.apnsToken) {
      await this.scheduleNextMorningBrief();
    }
    if (this.env.DISABLED === "1") return;

    const { latitude, longitude } = this.state;
    let temperature: string | undefined;
    let condition: string | undefined;

    if (latitude !== null && longitude !== null) {
      try {
        const current = await fetchCurrentConditions(
          latitude,
          longitude,
          this.state.temperatureUnit,
        );
        temperature = current?.temperature;
        condition = current?.condition;
      } catch {
        // Brief still goes out without the numbers — same fallback copy the app uses.
      }
    }

    await this.deliver({
      payload: buildMorningBriefPayload({
        hour: this.state.morningBriefHour,
        locationName: this.state.locationName ?? undefined,
        temperature,
        condition,
        soundsEnabled: this.state.soundsEnabled,
      }),
      pushType: "alert",
      collapseId: "daycast-morning-brief",
    });
  }

  // MARK: - Operator-triggered sends

  async sendCustom(input: {
    title: string;
    body: string;
    subtitle?: string;
    deepLink?: string;
  }): Promise<DeliveryResult> {
    return this.deliver({
      payload: {
        aps: {
          alert: { title: input.title, subtitle: input.subtitle, body: input.body },
          sound: this.state.soundsEnabled ? "default" : undefined,
          category: "GROKCAST_SEVERE_ALERT",
          "thread-id": "daycast-messages",
        },
        deepLink: input.deepLink ?? "daycast://today",
      },
      pushType: "alert",
    });
  }

  /**
   * Silent wake. Priority 5 and push-type background are both required — APNs
   * rejects a content-available push sent at priority 10.
   */
  async sendSilentRefresh(): Promise<DeliveryResult> {
    return this.deliver({
      payload: buildSilentRefreshPayload(),
      pushType: "background",
      priority: 5,
      collapseId: "daycast-refresh",
    });
  }

  // MARK: - Delivery

  private credentials(): APNsCredentials {
    return {
      keyId: this.env.APNS_KEY_ID,
      teamId: this.env.APNS_TEAM_ID,
      privateKeyPEM: this.env.APNS_KEY_P8,
      bundleId: this.env.APNS_BUNDLE_ID,
    };
  }

  private async deliver(request: {
    payload: unknown;
    pushType: "alert" | "background";
    priority?: 5 | 10;
    expiration?: number;
    collapseId?: string;
  }): Promise<DeliveryResult> {
    const token = this.state.apnsToken;
    if (!token) {
      return { ok: false, attempted: false, reason: "NotRegistered", tokenIsDead: false };
    }
    if (this.env.DISABLED === "1") {
      return { ok: false, attempted: false, reason: "ServiceDisabled", tokenIsDead: false };
    }

    const result = await sendAPNs(this.credentials(), {
      deviceToken: token,
      environment: this.state.environment,
      payload: request.payload,
      pushType: request.pushType,
      priority: request.priority,
      expiration: request.expiration,
      collapseId: request.collapseId,
    });

    if (result.tokenIsDead) {
      // APNs will never accept this token again. Drop it and stop the polling
      // schedule so a reinstalled app doesn't leave a DO burning requests forever.
      await this.cancelAll();
      this.setState({
        ...this.state,
        apnsToken: null,
        lastError: `token dropped: ${result.reason ?? result.status}`,
      });
    } else if (!result.ok) {
      this.setState({
        ...this.state,
        lastError: `apns ${result.status} ${result.reason ?? ""}`.trim(),
      });
    } else {
      this.setState({ ...this.state, lastPushAt: Date.now(), lastError: null });
    }

    return { ...result, attempted: true };
  }
}

function capIds(ids: string[]): string[] {
  const unique = [...new Set(ids)];
  return unique.slice(-MAX_REMEMBERED_ALERT_IDS);
}
