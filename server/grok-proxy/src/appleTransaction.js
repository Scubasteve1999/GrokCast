/**
 * Verifies a StoreKit 2 signed transaction (`VerificationResult.jwsRepresentation`).
 *
 * This is the proxy's only credential. The shared `PROXY_SECRET` is shipped
 * inside the app binary and must be treated as public; entitlement comes from
 * the JWS alone, because only Apple can mint one.
 */

import { APPLE_ROOT_CA_G3 } from "./appleRoot.js";
import { importPublicKey, parseCertificate, verifyChain } from "./x509.js";

const DEFAULT_MAX_SIGNED_AGE_MS = 30 * 24 * 60 * 60 * 1000;

export class TransactionError extends Error {
  constructor(message) {
    super(message);
    this.name = "TransactionError";
  }
}

function base64urlToBytes(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const base64 = padded + "=".repeat((4 - (padded.length % 4)) % 4);
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

function base64urlToJSON(value) {
  return JSON.parse(new TextDecoder().decode(base64urlToBytes(value)));
}

/**
 * @returns {Promise<{originalTransactionId: string, transactionId: string,
 *   productId: string, environment: string, expiresDate: number|null}>}
 */
export async function verifyTransaction(jws, options) {
  const {
    bundleId,
    productIds,
    environments = ["Production", "Sandbox"],
    now = Date.now(),
    rootCertificate = APPLE_ROOT_CA_G3,
    maxSignedAgeMs = DEFAULT_MAX_SIGNED_AGE_MS,
  } = options;

  if (typeof jws !== "string" || jws.length === 0) {
    throw new TransactionError("missing transaction");
  }

  const parts = jws.split(".");
  if (parts.length !== 3) throw new TransactionError("malformed transaction");
  const [encodedHeader, encodedPayload, encodedSignature] = parts;

  let header;
  try {
    header = base64urlToJSON(encodedHeader);
  } catch {
    throw new TransactionError("malformed transaction header");
  }

  if (header.alg !== "ES256") throw new TransactionError("unexpected signing algorithm");
  if (!Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new TransactionError("missing certificate chain");
  }

  let chain;
  try {
    chain = header.x5c.map((certificate) =>
      parseCertificate(Uint8Array.from(atob(certificate), (c) => c.charCodeAt(0)))
    );
  } catch (error) {
    throw new TransactionError(`unreadable certificate chain: ${error.message}`);
  }

  let leaf;
  try {
    leaf = await verifyChain(chain, rootCertificate, now);
  } catch (error) {
    throw new TransactionError(`untrusted certificate chain: ${error.message}`);
  }

  if (leaf.curve.name !== "P-256") throw new TransactionError("unexpected leaf key curve");

  // JWS carries the raw r||s signature, unlike the DER form inside certificates.
  const signature = base64urlToBytes(encodedSignature);
  if (signature.length !== 64) throw new TransactionError("malformed signature");

  const signingInput = new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`);
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    await importPublicKey(leaf),
    signature,
    signingInput
  );
  if (!verified) throw new TransactionError("signature verification failed");

  let payload;
  try {
    payload = base64urlToJSON(encodedPayload);
  } catch {
    throw new TransactionError("malformed transaction payload");
  }

  if (payload.bundleId !== bundleId) throw new TransactionError("wrong bundle");
  if (!productIds.includes(payload.productId)) throw new TransactionError("not a Pro product");
  if (!environments.includes(payload.environment)) {
    throw new TransactionError(`environment not allowed: ${payload.environment}`);
  }
  if (payload.revocationDate) throw new TransactionError("transaction revoked");
  if (payload.expiresDate && payload.expiresDate <= now) {
    throw new TransactionError("subscription expired");
  }

  // Apple re-signs on every entitlement refresh. Requiring a recent signature is
  // what stops a refunded user replaying a token minted before the refund.
  if (typeof payload.signedDate === "number" && now - payload.signedDate > maxSignedAgeMs) {
    throw new TransactionError("stale transaction — refresh entitlements");
  }

  const originalTransactionId = payload.originalTransactionId ?? payload.transactionId;
  if (!originalTransactionId) throw new TransactionError("missing transaction id");

  return {
    originalTransactionId: String(originalTransactionId),
    transactionId: String(payload.transactionId ?? originalTransactionId),
    productId: payload.productId,
    environment: payload.environment,
    expiresDate: payload.expiresDate ?? null,
  };
}
