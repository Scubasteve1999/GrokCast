import assert from "node:assert/strict";
import test from "node:test";

import { verifyTransaction } from "../src/appleTransaction.js";
import {
  BUNDLE_ID,
  fixtures,
  mintTransaction,
  MONTHLY,
  PRO_PRODUCT_IDS,
  TEST_ROOT,
  YEARLY,
} from "./helpers.js";

const options = { bundleId: BUNDLE_ID, productIds: PRO_PRODUCT_IDS, rootCertificate: TEST_ROOT };

async function expectRejection(overrides, pattern) {
  const jws = await mintTransaction(overrides);
  await assert.rejects(() => verifyTransaction(jws, options), pattern);
}

test("a valid transaction yields the entitlement", async () => {
  const jws = await mintTransaction();
  const entitlement = await verifyTransaction(jws, options);

  assert.equal(entitlement.originalTransactionId, "2000000800000001");
  assert.equal(entitlement.productId, YEARLY);
  assert.equal(entitlement.environment, "Production");
});

test("the monthly product is accepted too", async () => {
  const jws = await mintTransaction({ productId: MONTHLY });
  assert.equal((await verifyTransaction(jws, options)).productId, MONTHLY);
});

test("originalTransactionId is used as the rate-limit subject even across renewals", async () => {
  const first = await mintTransaction({ transactionId: "1" });
  const second = await mintTransaction({ transactionId: "2" });

  const a = await verifyTransaction(first, options);
  const b = await verifyTransaction(second, options);

  assert.equal(a.originalTransactionId, b.originalTransactionId);
  assert.notEqual(a.transactionId, b.transactionId);
});

test("a tampered payload is rejected", async () => {
  await expectRejection({ tamperPayload: true }, /signature verification failed/);
});

test("a transaction signed by an untrusted chain is rejected", async () => {
  await expectRejection(
    { chain: [fixtures.rogueLeaf, fixtures.rogueRoot], privateKey: fixtures.rogueLeafPrivateKey },
    /untrusted certificate chain/
  );
});

test("a self-signed transaction with no chain is rejected", async () => {
  await expectRejection({ chain: [fixtures.leaf] }, /missing certificate chain/);
});

test("a transaction for another app is rejected", async () => {
  await expectRejection({ bundleId: "com.someone.else" }, /wrong bundle/);
});

test("a transaction for a non-Pro product is rejected", async () => {
  await expectRejection({ productId: "com.scubasteve1999.GrokCast.tip.small" }, /not a Pro product/);
});

test("a revoked transaction is rejected", async () => {
  await expectRejection({ revocationDate: Date.now() - 1000 }, /revoked/);
});

test("an expired subscription is rejected", async () => {
  await expectRejection({ expiresDate: Date.now() - 1000 }, /expired/);
});

test("a stale signature is rejected so refunds cannot be replayed", async () => {
  const jws = await mintTransaction({ signedDate: Date.now() - 60 * 86_400_000 });
  await assert.rejects(() => verifyTransaction(jws, options), /stale transaction/);
});

test("a sandbox transaction is rejected when only production is allowed", async () => {
  const jws = await mintTransaction({ environment: "Sandbox" });
  await assert.rejects(
    () => verifyTransaction(jws, { ...options, environments: ["Production"] }),
    /environment not allowed/
  );
});

test("a sandbox transaction is accepted when sandbox is allowed", async () => {
  const jws = await mintTransaction({ environment: "Sandbox" });
  const entitlement = await verifyTransaction(jws, {
    ...options,
    environments: ["Production", "Sandbox"],
  });
  assert.equal(entitlement.environment, "Sandbox");
});

test("the algorithm cannot be downgraded to none", async () => {
  await expectRejection({ header: { alg: "none" } }, /unexpected signing algorithm/);
});

test("garbage input is rejected without throwing an unexpected error", async () => {
  for (const value of ["", "a.b", "not-a-jws", null, undefined]) {
    await assert.rejects(() => verifyTransaction(value, options), /TransactionError/);
  }
});

test("verification is pinned — the real Apple root rejects our test chain", async () => {
  const jws = await mintTransaction();
  await assert.rejects(
    () => verifyTransaction(jws, { bundleId: BUNDLE_ID, productIds: PRO_PRODUCT_IDS }),
    /untrusted certificate chain/
  );
});
