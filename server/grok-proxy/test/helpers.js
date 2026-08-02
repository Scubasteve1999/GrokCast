/**
 * Test helpers: mint StoreKit-shaped JWS transactions signed by the throwaway
 * chain in fixtures.json, and an in-memory stand-in for Workers KV.
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const fixturesPath = fileURLToPath(new URL("./fixtures/fixtures.json", import.meta.url));

let fixturesJSON;
try {
  fixturesJSON = readFileSync(fixturesPath, "utf8");
} catch {
  throw new Error(
    "Test fixtures are missing. They hold private keys, so they are never committed —\n" +
      "generate a fresh throwaway chain with:  npm run fixtures"
  );
}

export const fixtures = JSON.parse(fixturesJSON);

export const BUNDLE_ID = "com.scubasteve1999.GrokCast";
export const MONTHLY = "com.scubasteve1999.GrokCast.pro.monthly";
export const YEARLY = "com.scubasteve1999.GrokCast.pro.yearly";
export const PRO_PRODUCT_IDS = [MONTHLY, YEARLY];

export function base64ToBytes(value) {
  return Uint8Array.from(Buffer.from(value, "base64"));
}

export const TEST_ROOT = base64ToBytes(fixtures.root);
export const ROGUE_ROOT = base64ToBytes(fixtures.rogueRoot);

function bytesToBase64url(bytes) {
  return Buffer.from(bytes).toString("base64url");
}

function jsonToBase64url(value) {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

/** Builds a signed transaction. Override anything to produce a bad one. */
export async function mintTransaction(overrides = {}) {
  const {
    chain = [fixtures.leaf, fixtures.intermediate, fixtures.root],
    privateKey = fixtures.leafPrivateKey,
    header: headerOverrides = {},
    tamperPayload = false,
    now = Date.now(),
    ...payloadOverrides
  } = overrides;

  const header = { alg: "ES256", x5c: chain, ...headerOverrides };

  const payload = {
    transactionId: "2000000900000001",
    originalTransactionId: "2000000800000001",
    bundleId: BUNDLE_ID,
    productId: YEARLY,
    type: "Auto-Renewable Subscription",
    environment: "Production",
    purchaseDate: now - 86_400_000,
    signedDate: now,
    expiresDate: now + 30 * 86_400_000,
    ...payloadOverrides,
  };

  const encodedHeader = jsonToBase64url(header);
  const encodedPayload = jsonToBase64url(payload);

  const key = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: { name: "SHA-256" } },
      key,
      new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`)
    )
  );

  const finalPayload = tamperPayload
    ? jsonToBase64url({ ...payload, productId: "com.example.free" })
    : encodedPayload;

  return `${encodedHeader}.${finalPayload}.${bytesToBase64url(signature)}`;
}

/** Minimal Workers KV stand-in. Ignores TTL — tests drive the clock directly. */
export function memoryKV(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    store,
    async get(key) {
      return store.has(key) ? store.get(key) : null;
    },
    async put(key, value) {
      store.set(key, String(value));
    },
    async delete(key) {
      store.delete(key);
    },
    async list({ prefix = "", cursor } = {}) {
      // Workers KV pages results; tests page at 2 keys so pagination is exercised
      // rather than assumed.
      const all = [...store.keys()].filter((k) => k.startsWith(prefix)).sort();
      const start = cursor ? Number.parseInt(cursor, 10) : 0;
      const page = all.slice(start, start + 2);
      const next = start + page.length;
      return {
        keys: page.map((name) => ({ name })),
        list_complete: next >= all.length,
        cursor: next >= all.length ? undefined : String(next),
      };
    },
  };
}

export function testEnv(overrides = {}) {
  return {
    XAI_API_KEY: "xai-test-server-key",
    PROXY_SECRET: "test-proxy-secret",
    BUNDLE_ID,
    PRO_PRODUCT_IDS: PRO_PRODUCT_IDS.join(","),
    ALLOWED_ENVIRONMENTS: "Production,Sandbox",
    DAILY_CHAT_LIMIT: "3",
    DAILY_IMAGE_LIMIT: "2",
    GLOBAL_DAILY_LIMIT: "100",
    DISABLED: "0",
    USAGE: memoryKV(),
    ...overrides,
  };
}

export function proxyRequest({
  path = "/v1/chat/completions",
  method = "POST",
  secret = "test-proxy-secret",
  transaction,
  body = JSON.stringify({ model: "grok-3-mini", messages: [] }),
} = {}) {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (secret !== null) headers.set("Authorization", `Bearer ${secret}`);
  if (transaction) headers.set("X-SpotterCast-Transaction", transaction);

  const hasBody = method !== "GET" && method !== "HEAD";
  return new Request(`https://proxy.example.com${path}`, {
    method,
    headers,
    body: hasBody ? body : undefined,
  });
}
