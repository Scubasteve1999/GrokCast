import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { test } from "node:test";

import type { APNsCredentials } from "../src/apns.ts";
import {
  clearProviderTokenCache,
  createProviderToken,
  decodePKCS8,
  isDeadTokenResponse,
  sendAPNs,
} from "../src/apns.ts";

// A throwaway P-256 key, generated per run. Same reasoning as grok-proxy's
// fixtures: never check a private key into the repo.
function testCredentials(): APNsCredentials {
  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
    privateKeyEncoding: { type: "pkcs8", format: "pem" },
    publicKeyEncoding: { type: "spki", format: "pem" },
  });
  return {
    keyId: "ABCDE12345",
    teamId: "TEAM123456",
    privateKeyPEM: privateKey as unknown as string,
    bundleId: "com.scubasteve1999.GrokCast",
  };
}

function decodeSegment(segment: string): Record<string, unknown> {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
}

test("decodePKCS8 accepts real newlines and shell-escaped \\n alike", () => {
  const { privateKeyPEM } = testCredentials();
  const escaped = privateKeyPEM.replace(/\n/g, "\\n");
  assert.deepEqual(decodePKCS8(privateKeyPEM), decodePKCS8(escaped));
});

test("decodePKCS8 rejects anything that is not a PKCS#8 PEM", () => {
  assert.throws(() => decodePKCS8("not-a-key"), /PKCS#8/);
});

test("createProviderToken mints an ES256 JWT with the kid and team id APNs expects", async () => {
  clearProviderTokenCache();
  const credentials = testCredentials();
  const jwt = await createProviderToken(credentials);

  const [header, claims, signature] = jwt.split(".");
  assert.deepEqual(decodeSegment(header), {
    alg: "ES256",
    kid: "ABCDE12345",
    typ: "JWT",
  });
  assert.equal(decodeSegment(claims).iss, "TEAM123456");
  // Raw r||s for P-256 is 64 bytes; base64url of that is 86 chars unpadded.
  assert.equal(signature.length, 86);
  // base64url must not leak padding or the +/ alphabet.
  assert.doesNotMatch(jwt, /[+/=]/);
});

test("provider tokens are reused inside the window and reminted past it", async () => {
  clearProviderTokenCache();
  const credentials = testCredentials();

  const first = await createProviderToken(credentials, 0);
  const cached = await createProviderToken(credentials, 44 * 60 * 1000);
  assert.equal(cached, first, "should reuse — APNs rejects reminting inside 20 minutes");

  const refreshed = await createProviderToken(credentials, 46 * 60 * 1000);
  assert.notEqual(refreshed, first, "should remint — APNs rejects tokens over an hour old");
});

test("isDeadTokenResponse separates permanent token failures from transient ones", () => {
  assert.equal(isDeadTokenResponse(410, "Unregistered"), true);
  assert.equal(isDeadTokenResponse(400, "BadDeviceToken"), true);
  assert.equal(isDeadTokenResponse(400, "DeviceTokenNotForTopic"), true);
  // Retryable: a bad payload or a throttle must not cost the user their token.
  assert.equal(isDeadTokenResponse(400, "PayloadTooLarge"), false);
  assert.equal(isDeadTokenResponse(429, "TooManyRequests"), false);
  assert.equal(isDeadTokenResponse(500, "InternalServerError"), false);
  assert.equal(isDeadTokenResponse(403, undefined), false);
});

test("sendAPNs targets the right host and sets the required APNs headers", async () => {
  clearProviderTokenCache();
  const credentials = testCredentials();
  let seenUrl = "";
  let seenHeaders: Record<string, string> = {};

  const fetchImpl = (async (url: string, init: RequestInit) => {
    seenUrl = url;
    seenHeaders = init.headers as Record<string, string>;
    return new Response(null, { status: 200, headers: { "apns-id": "abc-123" } });
  }) as unknown as typeof fetch;

  const result = await sendAPNs(
    credentials,
    {
      deviceToken: "deadbeef",
      environment: "production",
      payload: { aps: { alert: { title: "t", body: "b" } } },
      pushType: "alert",
      expiration: 1_800_000_000,
      collapseId: "urn:oid:1",
    },
    fetchImpl,
  );

  assert.equal(seenUrl, "https://api.push.apple.com/3/device/deadbeef");
  assert.equal(seenHeaders["apns-topic"], "com.scubasteve1999.GrokCast");
  assert.equal(seenHeaders["apns-push-type"], "alert");
  assert.equal(seenHeaders["apns-priority"], "10");
  assert.equal(seenHeaders["apns-expiration"], "1800000000");
  assert.equal(seenHeaders["apns-collapse-id"], "urn:oid:1");
  assert.match(seenHeaders.authorization, /^bearer eyJ/);
  assert.deepEqual(result, { ok: true, status: 200, apnsId: "abc-123", tokenIsDead: false });
});

test("sendAPNs uses the sandbox host and priority 5 for background pushes", async () => {
  clearProviderTokenCache();
  let seenUrl = "";
  let seenHeaders: Record<string, string> = {};

  const fetchImpl = (async (url: string, init: RequestInit) => {
    seenUrl = url;
    seenHeaders = init.headers as Record<string, string>;
    return new Response(null, { status: 200 });
  }) as unknown as typeof fetch;

  await sendAPNs(
    testCredentials(),
    {
      deviceToken: "cafe",
      environment: "sandbox",
      payload: { aps: { "content-available": 1 } },
      pushType: "background",
    },
    fetchImpl,
  );

  assert.equal(seenUrl, "https://api.sandbox.push.apple.com/3/device/cafe");
  // APNs rejects content-available at priority 10, so the default must be 5.
  assert.equal(seenHeaders["apns-priority"], "5");
});

test("sendAPNs surfaces the APNs reason and flags a dead token", async () => {
  clearProviderTokenCache();
  const fetchImpl = (async () =>
    new Response(JSON.stringify({ reason: "Unregistered" }), {
      status: 410,
    })) as unknown as typeof fetch;

  const result = await sendAPNs(
    testCredentials(),
    {
      deviceToken: "stale",
      environment: "production",
      payload: {},
      pushType: "alert",
    },
    fetchImpl,
  );

  assert.equal(result.ok, false);
  assert.equal(result.reason, "Unregistered");
  assert.equal(result.tokenIsDead, true);
});

test("an unreadable error body is treated as transient, not as a dead token", async () => {
  clearProviderTokenCache();
  const fetchImpl = (async () =>
    new Response("<html>gateway</html>", { status: 503 })) as unknown as typeof fetch;

  const result = await sendAPNs(
    testCredentials(),
    { deviceToken: "x", environment: "production", payload: {}, pushType: "alert" },
    fetchImpl,
  );

  assert.equal(result.ok, false);
  assert.equal(result.reason, undefined);
  assert.equal(result.tokenIsDead, false);
});

test("a transport failure is reported, not thrown, and never kills the token", async () => {
  clearProviderTokenCache();
  // What `wrangler dev` produces for every APNs call, since workerd cannot do
  // outbound HTTP/2 locally (cloudflare/workerd#4841).
  const fetchImpl = (async () => {
    throw new TypeError("Network connection lost.");
  }) as unknown as typeof fetch;

  const result = await sendAPNs(
    testCredentials(),
    { deviceToken: "x", environment: "production", payload: {}, pushType: "alert" },
    fetchImpl,
  );

  assert.equal(result.ok, false);
  assert.equal(result.status, 0);
  assert.equal(result.reason, "Network connection lost.");
  assert.equal(result.tokenIsDead, false);
});

test("collapse ids longer than the APNs 64-byte limit are truncated", async () => {
  clearProviderTokenCache();
  let seenHeaders: Record<string, string> = {};
  const fetchImpl = (async (_url: string, init: RequestInit) => {
    seenHeaders = init.headers as Record<string, string>;
    return new Response(null, { status: 200 });
  }) as unknown as typeof fetch;

  await sendAPNs(
    testCredentials(),
    {
      deviceToken: "x",
      environment: "production",
      payload: {},
      pushType: "alert",
      collapseId: "z".repeat(100),
    },
    fetchImpl,
  );

  assert.equal(seenHeaders["apns-collapse-id"].length, 64);
});
