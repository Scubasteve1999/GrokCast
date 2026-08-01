/**
 * X.509 parsing and ECDSA chain verification, built on WebCrypto only.
 *
 * Scope is exactly what Apple's App Store signed-data chain needs: EC keys on
 * P-256/P-384 signed with ECDSA-SHA256/384. RSA is intentionally unsupported —
 * Apple does not use it here, and accepting it would widen the trusted set.
 */

import { TAG, bitStringBytes, decodeOID, decodeTime, readChildren, readTLV } from "./asn1.js";

const OID = {
  ecPublicKey: "1.2.840.10045.2.1",
  prime256v1: "1.2.840.10045.3.1.7",
  secp384r1: "1.3.132.0.34",
  ecdsaWithSHA256: "1.2.840.10045.4.3.2",
  ecdsaWithSHA384: "1.2.840.10045.4.3.3",
};

const CURVE = {
  [OID.prime256v1]: { name: "P-256", size: 32 },
  [OID.secp384r1]: { name: "P-384", size: 48 },
};

const SIGNATURE_ALGORITHM = {
  [OID.ecdsaWithSHA256]: "SHA-256",
  [OID.ecdsaWithSHA384]: "SHA-384",
};

/**
 * Parses a DER certificate into the pieces verification needs.
 *
 * Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
 * TBSCertificate ::= SEQUENCE { [0] version, serialNumber, signature,
 *                               issuer, validity, subject, subjectPublicKeyInfo, ... }
 */
export function parseCertificate(der) {
  const bytes = der instanceof Uint8Array ? der : new Uint8Array(der);
  const certificate = readTLV(bytes);
  if (certificate.tag !== TAG.SEQUENCE) throw new Error("x509: not a certificate");

  const [tbs, signatureAlgorithm, signatureValue] = readChildren(certificate);
  if (!tbs || !signatureAlgorithm || !signatureValue) throw new Error("x509: malformed certificate");

  const tbsFields = readChildren(tbs);
  // The version field is optional and context-tagged [0]; everything after it
  // is positional, so drop it before indexing.
  let index = tbsFields[0]?.tag === 0xa0 ? 1 : 0;
  index += 1; // serialNumber
  index += 1; // signature (repeats signatureAlgorithm)
  index += 1; // issuer
  const validity = tbsFields[index++];
  index += 1; // subject
  const spki = tbsFields[index];

  if (!validity || !spki) throw new Error("x509: malformed tbsCertificate");

  const [notBefore, notAfter] = readChildren(validity);
  const [spkiAlgorithm, spkiKey] = readChildren(spki);
  const [keyTypeOID, curveOID] = readChildren(spkiAlgorithm);

  if (decodeOID(keyTypeOID.contents) !== OID.ecPublicKey) {
    throw new Error("x509: only EC public keys are supported");
  }

  const curve = CURVE[decodeOID(curveOID.contents)];
  if (!curve) throw new Error("x509: unsupported curve");

  const [signatureAlgorithmOID] = readChildren(signatureAlgorithm);
  const hash = SIGNATURE_ALGORITHM[decodeOID(signatureAlgorithmOID.contents)];
  if (!hash) throw new Error("x509: unsupported signature algorithm");

  return {
    raw: bytes,
    /** Exact bytes the issuer signed. */
    tbs: tbs.full,
    /** Full SPKI triple — importable straight into WebCrypto. */
    spki: spki.full,
    curve,
    hash,
    signature: bitStringBytes(signatureValue),
    notBefore: decodeTime(notBefore),
    notAfter: decodeTime(notAfter),
    publicKeyBytes: bitStringBytes(spkiKey),
  };
}

/**
 * Converts an X.509 ECDSA signature (SEQUENCE of two INTEGERs) into the fixed
 * width r||s form WebCrypto expects.
 */
export function ecdsaDERToRaw(der, size) {
  const sequence = readTLV(der);
  if (sequence.tag !== TAG.SEQUENCE) throw new Error("x509: malformed ECDSA signature");

  const [r, s] = readChildren(sequence);
  if (!r || !s || r.tag !== TAG.INTEGER || s.tag !== TAG.INTEGER) {
    throw new Error("x509: malformed ECDSA signature");
  }

  const raw = new Uint8Array(size * 2);
  raw.set(normalizeInteger(r.contents, size), 0);
  raw.set(normalizeInteger(s.contents, size), size);
  return raw;
}

function normalizeInteger(contents, size) {
  let value = contents;
  // DER prefixes a 0x00 byte when the high bit would otherwise mean "negative".
  while (value.length > 1 && value[0] === 0x00) value = value.subarray(1);
  if (value.length > size) throw new Error("x509: ECDSA integer overflows curve");

  const padded = new Uint8Array(size);
  padded.set(value, size - value.length);
  return padded;
}

/** Imports a certificate's public key for verification. */
export async function importPublicKey(certificate) {
  return crypto.subtle.importKey(
    "spki",
    certificate.spki,
    { name: "ECDSA", namedCurve: certificate.curve.name },
    false,
    ["verify"]
  );
}

/** Verifies that `certificate` was signed by `issuer`. */
export async function verifyCertificateSignature(certificate, issuer) {
  const key = await importPublicKey(issuer);
  const signature = ecdsaDERToRaw(certificate.signature, issuer.curve.size);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: { name: certificate.hash } },
    key,
    signature,
    certificate.tbs
  );
}

export function bytesEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

/**
 * Verifies a leaf-first certificate chain terminates at `trustedRootDER`.
 *
 * Checks every link's signature and every certificate's validity window. Name
 * chaining, key usage, and revocation are not checked: the chain is pinned to a
 * single self-signed root we ship, so there is no path-building to constrain.
 */
export async function verifyChain(presented, trustedRootDER, now) {
  if (presented.length < 2) throw new Error("x509: chain too short");

  const trustedRoot = parseCertificate(trustedRootDER);
  const presentedRoot = presented[presented.length - 1];

  // Senders may or may not include the root in x5c. Appending our pinned copy
  // when it is absent keeps both shapes working; trust still comes only from
  // the pinned bytes, since every link is signature-checked up to them.
  const chain = bytesEqual(presentedRoot.raw, trustedRoot.raw)
    ? presented
    : [...presented, trustedRoot];

  for (const certificate of chain) {
    if (now < certificate.notBefore) throw new Error("x509: certificate not yet valid");
    if (now > certificate.notAfter) throw new Error("x509: certificate expired");
  }

  for (let i = 0; i < chain.length - 1; i++) {
    if (!(await verifyCertificateSignature(chain[i], chain[i + 1]))) {
      throw new Error(`x509: bad signature at chain position ${i}`);
    }
  }

  // The root is self-signed; verifying it catches a corrupted pinned copy.
  const root = chain[chain.length - 1];
  if (!(await verifyCertificateSignature(root, root))) {
    throw new Error("x509: root self-signature failed");
  }

  return chain[0];
}
