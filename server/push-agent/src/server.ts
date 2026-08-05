import { getAgentByName } from "agents";

import type { Env, RegisterInput } from "./DeviceAgent.ts";
import { DeviceAgent } from "./DeviceAgent.ts";
import { bearerToken, secureCompare } from "./auth.ts";
import { isValidTimeZone } from "./time.ts";

export { DeviceAgent };

/**
 * Device ids are client-generated random UUIDs held in the Keychain, never
 * identifierForVendor. PUSH_SECRET ships inside the binary and is therefore
 * public — the id is what actually stops one device from unregistering another,
 * so it must stay unguessable. See README, "What the secrets do and don't buy".
 */
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function error(type: string, message: string, status: number): Response {
  return json({ error: { type, message } }, status);
}

interface RegisterBody extends Partial<RegisterInput> {
  deviceId?: string;
}

function validateRegister(body: RegisterBody): string | null {
  if (typeof body.apnsToken !== "string" || !/^[0-9a-fA-F]{64,200}$/.test(body.apnsToken)) {
    return "apnsToken must be a hex APNs device token";
  }
  if (typeof body.latitude !== "number" || body.latitude < -90 || body.latitude > 90) {
    return "latitude must be between -90 and 90";
  }
  if (typeof body.longitude !== "number" || body.longitude < -180 || body.longitude > 180) {
    return "longitude must be between -180 and 180";
  }
  if (typeof body.timeZone !== "string" || !isValidTimeZone(body.timeZone)) {
    return "timeZone must be a valid IANA identifier";
  }
  // Matches MorningBriefNotificationService.persistedHour, which clamps to 7...11.
  if (
    typeof body.morningBriefHour !== "number" ||
    !Number.isInteger(body.morningBriefHour) ||
    body.morningBriefHour < 0 ||
    body.morningBriefHour > 23
  ) {
    return "morningBriefHour must be an integer hour 0-23";
  }
  if (body.environment !== undefined && !["production", "sandbox"].includes(body.environment)) {
    return "environment must be 'production' or 'sandbox'";
  }
  if (
    body.temperatureUnit !== undefined &&
    !["fahrenheit", "celsius"].includes(body.temperatureUnit)
  ) {
    return "temperatureUnit must be 'fahrenheit' or 'celsius'";
  }
  return null;
}

/**
 * Route allowlist, for the same reason grok-proxy has one: a leaked secret must
 * not expose anything beyond these routes. Checked before auth and before any
 * body parsing, so unknown paths are a flat 404 with no other signal.
 */
const DEVICE_ROUTES = new Set(["/v1/push/register", "/v1/push/unregister", "/v1/push/status"]);
const ADMIN_ROUTES = new Set(["/v1/push/send", "/v1/push/refresh"]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env);
    } catch (cause) {
      // Never let a stack trace reach the client; the details go to the tail log.
      console.error("push-agent unhandled error", cause);
      return error("internal_error", "Request failed.", 500);
    }
  },
};

async function handle(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;

  // Unauthenticated liveness, same shape as grok-proxy's /v1/health.
  if (path === "/v1/push/health") {
    return json({ ok: true, disabled: env.DISABLED === "1" });
  }

  const isAdminRoute = ADMIN_ROUTES.has(path);
  if (!isAdminRoute && !DEVICE_ROUTES.has(path)) {
    return error("not_found", "Unknown route.", 404);
  }

  if (isAdminRoute) {
    const admin = request.headers.get("x-daycast-admin");
    if (!admin || !env.ADMIN_SECRET || !secureCompare(admin, env.ADMIN_SECRET)) {
      return error("unauthorized", "Invalid admin credential.", 401);
    }
  } else {
    const token = bearerToken(request.headers.get("authorization"));
    if (!token || !env.PUSH_SECRET || !secureCompare(token, env.PUSH_SECRET)) {
      return error("unauthorized", "Invalid credential.", 401);
    }
  }

  let body: RegisterBody;
  try {
    body = request.method === "GET" ? {} : ((await request.json()) as RegisterBody);
  } catch {
    return error("bad_request", "Body must be JSON.", 400);
  }

  const deviceId = body.deviceId ?? url.searchParams.get("deviceId") ?? "";
  if (!DEVICE_ID_PATTERN.test(deviceId)) {
    return error("bad_request", "deviceId must be 16-128 URL-safe characters.", 400);
  }

  const agent = await getAgentByName(env.DEVICE_AGENT, deviceId);

  switch (path) {
    case "/v1/push/register": {
      if (request.method !== "POST") return error("bad_request", "POST required.", 405);
      const invalid = validateRegister(body);
      if (invalid) return error("bad_request", invalid, 400);

      await agent.register({
        apnsToken: body.apnsToken as string,
        environment: body.environment,
        latitude: body.latitude as number,
        longitude: body.longitude as number,
        locationName: body.locationName,
        timeZone: body.timeZone as string,
        alertsEnabled: body.alertsEnabled === true,
        morningBriefEnabled: body.morningBriefEnabled === true,
        morningBriefHour: body.morningBriefHour as number,
        soundsEnabled: body.soundsEnabled !== false,
        temperatureUnit: body.temperatureUnit ?? "fahrenheit",
      });
      return json({ ok: true });
    }

    case "/v1/push/unregister": {
      if (request.method !== "POST") return error("bad_request", "POST required.", 405);
      await agent.unregister();
      return json({ ok: true });
    }

    case "/v1/push/status": {
      return json(await agent.status());
    }

    case "/v1/push/send": {
      if (request.method !== "POST") return error("bad_request", "POST required.", 405);
      const { title, body: message, subtitle, deepLink } = body as Record<string, string>;
      if (!title || !message) {
        return error("bad_request", "title and body are required.", 400);
      }
      return json(await agent.sendCustom({ title, body: message, subtitle, deepLink }));
    }

    case "/v1/push/refresh": {
      if (request.method !== "POST") return error("bad_request", "POST required.", 405);
      return json(await agent.sendSilentRefresh());
    }

    default:
      // Unreachable — the allowlist above already rejected anything else.
      return error("not_found", "Unknown route.", 404);
  }
}
