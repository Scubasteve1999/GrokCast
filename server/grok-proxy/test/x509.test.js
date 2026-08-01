import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { decodeOID, readChildren, readTLV, TAG } from "../src/asn1.js";
import { APPLE_ROOT_CA_G3 } from "../src/appleRoot.js";
import { ecdsaDERToRaw, parseCertificate, verifyChain } from "../src/x509.js";
import { base64ToBytes, fixtures, ROGUE_ROOT, TEST_ROOT } from "./helpers.js";

const APPLE_ROOT_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";

test("the pinned Apple root matches its published fingerprint", () => {
  const digest = createHash("sha256").update(APPLE_ROOT_CA_G3).digest("hex");
  assert.equal(digest, APPLE_ROOT_SHA256);
});

test("the pinned Apple root parses as a self-signed P-384 certificate", async () => {
  const root = parseCertificate(APPLE_ROOT_CA_G3);
  assert.equal(root.curve.name, "P-384");
  assert.equal(root.hash, "SHA-384");
  assert.ok(root.notAfter > Date.now(), "Apple root should not be expired");
  assert.ok(await verifyChain([root, root], APPLE_ROOT_CA_G3, Date.now()));
});

test("readTLV handles multi-byte lengths", () => {
  const payload = new Uint8Array(300).fill(0x41);
  const der = new Uint8Array([0x04, 0x82, 0x01, 0x2c, ...payload]);
  const tlv = readTLV(der);
  assert.equal(tlv.tag, TAG.OCTET_STRING);
  assert.equal(tlv.length, 300);
  assert.equal(tlv.contents.length, 300);
});

test("readTLV rejects a truncated value", () => {
  assert.throws(() => readTLV(new Uint8Array([0x04, 0x10, 0x01, 0x02])), /truncated/);
});

test("decodeOID decodes id-ecPublicKey", () => {
  const spki = readChildren(readChildren(readTLV(TEST_ROOT))[0]);
  assert.ok(spki.length > 0);
  assert.equal(decodeOID(new Uint8Array([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01])), "1.2.840.10045.2.1");
});

test("ecdsaDERToRaw left-pads short integers to the curve width", () => {
  // SEQUENCE { INTEGER 0x01, INTEGER 0x00ff }
  const der = new Uint8Array([0x30, 0x08, 0x02, 0x01, 0x01, 0x02, 0x03, 0x00, 0xff, 0xff]);
  const raw = ecdsaDERToRaw(der.subarray(0, 10), 32);
  assert.equal(raw.length, 64);
  assert.equal(raw[31], 0x01);
  assert.equal(raw[62], 0xff);
  assert.equal(raw[63], 0xff);
  assert.equal(raw.slice(0, 31).every((byte) => byte === 0), true);
});

test("a well-formed chain verifies against its own root", async () => {
  const chain = [fixtures.leaf, fixtures.intermediate, fixtures.root].map((certificate) =>
    parseCertificate(base64ToBytes(certificate))
  );
  const leaf = await verifyChain(chain, TEST_ROOT, Date.now());
  assert.equal(leaf.curve.name, "P-256");
});

test("a chain is rejected when it terminates at the wrong root", async () => {
  const chain = [fixtures.leaf, fixtures.intermediate, fixtures.root].map((certificate) =>
    parseCertificate(base64ToBytes(certificate))
  );
  await assert.rejects(
    () => verifyChain(chain, ROGUE_ROOT, Date.now()),
    /does not terminate at the pinned root/
  );
});

test("a chain is rejected when an intermediate is swapped out", async () => {
  const chain = [fixtures.leaf, fixtures.rogueLeaf, fixtures.root].map((certificate) =>
    parseCertificate(base64ToBytes(certificate))
  );
  // Rejected either as a bad signature or, when the substitute sits on a
  // different curve, as a signature that cannot belong to that key at all.
  await assert.rejects(() => verifyChain(chain, TEST_ROOT, Date.now()), /x509:/);
});

test("a chain is rejected outside the certificate validity window", async () => {
  const chain = [fixtures.leaf, fixtures.intermediate, fixtures.root].map((certificate) =>
    parseCertificate(base64ToBytes(certificate))
  );
  const longAgo = Date.parse("2000-01-01T00:00:00Z");
  await assert.rejects(() => verifyChain(chain, TEST_ROOT, longAgo), /not yet valid/);
});
