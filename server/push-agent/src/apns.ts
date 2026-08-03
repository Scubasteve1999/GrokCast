// APNs provider-token delivery, built on WebCrypto so it runs unchanged under
// Workers and `node --test`. Same approach as grok-proxy's x509.js — no runtime deps.

export interface APNsCredentials {
  keyId: string;
  teamId: string;
  /** Contents of the AuthKey_XXXXXXXXXX.p8 file (PKCS#8 PEM). */
  privateKeyPEM: string;
  bundleId: string;
}

export type APNsEnvironment = "production" | "sandbox";

export type APNsPushType = "alert" | "background";

export interface APNsRequest {
  deviceToken: string;
  environment: APNsEnvironment;
  payload: unknown;
  pushType: APNsPushType;
  /** 10 = deliver immediately, 5 = power-considerate. Background pushes must use 5. */
  priority?: 5 | 10;
  /** Seconds since epoch after which APNs stops retrying. 0 = try once, then drop. */
  expiration?: number;
  /** Later pushes with the same id replace earlier undelivered ones. Max 64 bytes. */
  collapseId?: string;
}

export interface APNsResult {
  ok: boolean;
  status: number;
  /** APNs `reason` string, e.g. "BadDeviceToken". Absent on success. */
  reason?: string;
  apnsId?: string;
  /**
   * True when APNs says this token will never work again. The caller must drop it
   * from state — retrying is what gets a provider rate-limited.
   */
  tokenIsDead: boolean;
}

const HOSTS: Record<APNsEnvironment, string> = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

// APNs rejects provider tokens older than 1 hour and rejects re-issuing more than
// once every 20 minutes. 45 minutes sits safely inside both bounds.
const TOKEN_TTL_MS = 45 * 60 * 1000;

interface CachedToken {
  jwt: string;
  issuedAt: number;
}

const tokenCache = new Map<string, CachedToken>();

/** Exposed for tests; also worth calling if credentials are rotated in place. */
export function clearProviderTokenCache(): void {
  tokenCache.clear();
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlEncodeJSON(value: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

/**
 * Parses a PKCS#8 PEM into raw DER. Apple ships .p8 files with literal newlines,
 * but environments that pass secrets through shells often turn those into "\n",
 * so both forms are accepted.
 */
export function decodePKCS8(pem: string): Uint8Array {
  const normalized = pem.replace(/\\n/g, "\n");
  const match = normalized.match(
    /-----BEGIN PRIVATE KEY-----([\s\S]*?)-----END PRIVATE KEY-----/,
  );
  if (!match) {
    throw new Error("APNS_KEY_P8 is not a PKCS#8 PEM private key");
  }
  const body = match[1].replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Mints (or reuses) the ES256 provider token APNs expects in the Authorization
 * header. WebCrypto's ECDSA output is already the raw r||s that JOSE wants, so
 * there is no DER unwrapping to do here.
 */
export async function createProviderToken(
  credentials: APNsCredentials,
  now: number = Date.now(),
): Promise<string> {
  const cacheKey = `${credentials.teamId}:${credentials.keyId}`;
  const cached = tokenCache.get(cacheKey);
  if (cached && now - cached.issuedAt < TOKEN_TTL_MS) {
    return cached.jwt;
  }

  const key = await crypto.subtle.importKey(
    "pkcs8",
    decodePKCS8(credentials.privateKeyPEM) as unknown as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const header = base64UrlEncodeJSON({
    alg: "ES256",
    kid: credentials.keyId,
    typ: "JWT",
  });
  const claims = base64UrlEncodeJSON({
    iss: credentials.teamId,
    iat: Math.floor(now / 1000),
  });
  const signingInput = `${header}.${claims}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
  tokenCache.set(cacheKey, { jwt, issuedAt: now });
  return jwt;
}

/**
 * Reasons that mean "this token is gone" rather than "try again later".
 * Anything else — including 429 and 5xx — is transient and safe to retry.
 */
const DEAD_TOKEN_REASONS = new Set([
  "BadDeviceToken",
  "Unregistered",
  "DeviceTokenNotForTopic",
]);

export function isDeadTokenResponse(status: number, reason?: string): boolean {
  if (status === 410) return true;
  return status === 400 && reason !== undefined && DEAD_TOKEN_REASONS.has(reason);
}

export async function sendAPNs(
  credentials: APNsCredentials,
  request: APNsRequest,
  fetchImpl: typeof fetch = fetch,
): Promise<APNsResult> {
  const jwt = await createProviderToken(credentials);
  const host = HOSTS[request.environment];

  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    "apns-topic": credentials.bundleId,
    "apns-push-type": request.pushType,
    "apns-priority": String(request.priority ?? (request.pushType === "background" ? 5 : 10)),
    "content-type": "application/json",
  };
  if (request.expiration !== undefined) {
    headers["apns-expiration"] = String(request.expiration);
  }
  if (request.collapseId) {
    headers["apns-collapse-id"] = request.collapseId.slice(0, 64);
  }

  let response: Response;
  try {
    response = await fetchImpl(`${host}/3/device/${request.deviceToken}`, {
      method: "POST",
      headers,
      body: JSON.stringify(request.payload),
    });
  } catch (cause) {
    // APNs is HTTP/2-only. Deployed Workers negotiate that fine, but `wrangler dev`
    // cannot (cloudflare/workerd#4841), so this path is what local dev always hits.
    // Either way a transport failure is transient — never grounds to drop the token.
    return {
      ok: false,
      status: 0,
      reason: cause instanceof Error ? cause.message : "NetworkError",
      tokenIsDead: false,
    };
  }

  const apnsId = response.headers.get("apns-id") ?? undefined;

  if (response.status === 200) {
    return { ok: true, status: 200, apnsId, tokenIsDead: false };
  }

  // Failures carry a JSON body; treat an unreadable one as an unknown transient error
  // rather than assuming the token is dead.
  let reason: string | undefined;
  try {
    const body = (await response.json()) as { reason?: string };
    reason = body?.reason;
  } catch {
    reason = undefined;
  }

  return {
    ok: false,
    status: response.status,
    reason,
    apnsId,
    tokenIsDead: isDeadTokenResponse(response.status, reason),
  };
}
