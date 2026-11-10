"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  db,
  Timestamp,
  clearEmulators,
  createUser,
  seedScenario,
  callApprove,
  callReject,
} = require("./emulator_helpers");

test.beforeEach(clearEmulators);

async function rejectsWith(run, code, reason) {
  await assert.rejects(run, (error) => {
    assert.equal(error.code, code);
    if (reason) assert.equal(error.details?.reason, reason);
    return true;
  });
}

test("authorized merchant executes the real callable transaction", async () => {
  const scenario = await seedScenario();
  const result = await callApprove(scenario.merchant.token);
  assert.equal(result.success, true);
  assert.equal(result.status, "approved");
  const checkIn = (await db.doc("checkIns/checkin-1").get()).data();
  assert.equal(checkIn.status, "approved");
  assert.equal(checkIn.validatedBy, scenario.merchant.uid);
});

test("unauthenticated caller is rejected", async () => {
  await seedScenario();
  await rejectsWith(() => callApprove(null), "UNAUTHENTICATED");
});

test("client cannot approve", async () => {
  const scenario = await seedScenario();
  await rejectsWith(() => callApprove(scenario.customer.token), "PERMISSION_DENIED");
});

test("merchant from another restaurant is isolated", async () => {
  const scenario = await seedScenario();
  const other = await createUser("merchant-other", "merchant");
  await db.doc(`merchants/${other.uid}`).set({ restaurantId: "restaurant-2" });
  await rejectsWith(() => callApprove(other.token), "PERMISSION_DENIED");
  assert.equal((await db.doc("checkIns/checkin-1").get()).data().status, "pending");
  void scenario;
});

test("missing check-in is rejected", async () => {
  const scenario = await seedScenario();
  await rejectsWith(() => callApprove(scenario.merchant.token, "missing"), "NOT_FOUND");
});

test("expired check-in leaves no partial state", async () => {
  const scenario = await seedScenario({
    checkIn: { expiresAt: Timestamp.fromMillis(Date.now() - 1_000) },
  });
  await rejectsWith(
    () => callApprove(scenario.merchant.token),
    "FAILED_PRECONDITION",
    "check-in-expired"
  );
  assert.equal((await db.collection("visits").get()).size, 0);
  assert.equal((await db.doc("checkIns/checkin-1").get()).data().status, "pending");
});

test("rejected check-in cannot be approved", async () => {
  const scenario = await seedScenario({ checkIn: { status: "rejected" } });
  await rejectsWith(
    () => callApprove(scenario.merchant.token),
    "FAILED_PRECONDITION",
    "check-in-rejected"
  );
});

test("normal approval creates exactly one visit and awards server points", async () => {
  const scenario = await seedScenario({ restaurant: { pointsPerVisit: 275 } });
  const result = await callApprove(scenario.merchant.token);
  assert.equal(result.pointsAwarded, 275);
  assert.equal((await db.collection("visits").get()).size, 1);
  assert.equal((await db.doc("checkIns/checkin-1").get()).data().pointsAwarded, 275);
});

test("threshold creates one deterministic reward", async () => {
  const scenario = await seedScenario({ restaurant: { rewardThreshold: 1 } });
  const result = await callApprove(scenario.merchant.token);
  assert.equal(result.rewardId, `${scenario.restaurantId}_${scenario.customer.uid}_cycle_1`);
  assert.equal((await db.collection("rewards").get()).size, 1);
});

test("an already used reward is preserved", async () => {
  const scenario = await seedScenario({ restaurant: { rewardThreshold: 1 } });
  const rewardId = `${scenario.restaurantId}_${scenario.customer.uid}_cycle_1`;
  await db.doc(`rewards/${rewardId}`).set({
    userId: scenario.customer.uid,
    restaurantId: scenario.restaurantId,
    status: "used",
    label: "Café offert",
  });
  const result = await callApprove(scenario.merchant.token);
  assert.equal(result.rewardId, null);
  assert.equal((await db.doc(`rewards/${rewardId}`).get()).data().status, "used");
});

test("secure rejection is idempotent and creates no loyalty data", async () => {
  const scenario = await seedScenario();
  const first = await callReject(scenario.merchant.token);
  const replay = await callReject(scenario.merchant.token);
  assert.equal(first.status, "rejected");
  assert.equal(replay.alreadyProcessed, true);
  assert.equal((await db.collection("visits").get()).size, 0);
  assert.equal((await db.collection("rewards").get()).size, 0);
  assert.equal((await db.doc("checkIns/checkin-1").get()).data().rejectedBy,
    scenario.merchant.uid);
});

test("client and unrelated merchant cannot securely reject", async () => {
  const scenario = await seedScenario();
  await rejectsWith(() => callReject(scenario.customer.token), "PERMISSION_DENIED");
  const other = await createUser("reject-merchant-other", "merchant");
  await db.doc(`merchants/${other.uid}`).set({ restaurantId: "restaurant-2" });
  await rejectsWith(() => callReject(other.token), "PERMISSION_DENIED");
  assert.equal((await db.doc("checkIns/checkin-1").get()).data().status, "pending");
});

test("approval and rejection cannot both win", async () => {
  const scenario = await seedScenario();
  const results = await Promise.allSettled([
    callApprove(scenario.merchant.token),
    callReject(scenario.merchant.token),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  const checkIn = (await db.doc("checkIns/checkin-1").get()).data();
  assert.ok(checkIn.status === "approved" || checkIn.status === "rejected");
  assert.equal((await db.collection("visits").get()).size,
    checkIn.status === "approved" ? 1 : 0);
});

test("first confirmed visit rewards referral exactly once", async () => {
  const scenario = await seedScenario();
  await db.doc(`referrals/initial_${scenario.customer.uid}`).set({
    referrerId: "referrer-emulator",
    referredUserId: scenario.customer.uid,
    name: "Sophie",
    status: "pending",
    pointsEarned: 0,
    invitedAt: Timestamp.now(),
  });

  const first = await callApprove(scenario.merchant.token);
  const replay = await callApprove(scenario.merchant.token);
  const referral = (
    await db.doc(`referrals/initial_${scenario.customer.uid}`).get()
  ).data();
  assert.equal(referral.status, "rewarded");
  assert.equal(referral.pointsEarned, 500);
  assert.deepEqual(first.referralRewardIds, [
    `initial_${scenario.customer.uid}`,
  ]);
  assert.deepEqual(replay.referralRewardIds, first.referralRewardIds);
  assert.equal(
    (await db.collection("notifications")
      .where("type", "==", "referral_rewarded").get()).size,
    1
  );
});

test("second visit and already rewarded referral receive no bonus", async () => {
  const scenario = await seedScenario({
    restaurant: { validationPolicy: "perTransaction" },
  });
  await Promise.all([
    db.doc("visits/previous").set({
      userId: scenario.customer.uid,
      restaurantId: scenario.restaurantId,
      timestamp: Timestamp.fromMillis(Date.now() - 86_400_000),
      checkInId: "previous-checkin",
      operationId: "approveCheckIn:previous-checkin",
    }),
    db.doc(`referrals/initial_${scenario.customer.uid}`).set({
      referrerId: "referrer-emulator",
      referredUserId: scenario.customer.uid,
      status: "pending",
      pointsEarned: 0,
      invitedAt: Timestamp.now(),
    }),
  ]);
  const result = await callApprove(scenario.merchant.token);
  assert.deepEqual(result.referralRewardIds, []);
  assert.equal(
    (await db.doc(`referrals/initial_${scenario.customer.uid}`).get()).data()
      .status,
    "pending"
  );
});

test("notification id is deterministic and unique", async () => {
  const scenario = await seedScenario();
  await callApprove(scenario.merchant.token);
  await callApprove(scenario.merchant.token);
  const notifications = await db.collection("notifications").get();
  assert.equal(notifications.size, 1);
  assert.equal(notifications.docs[0].id, "checkin-sync-checkin-1");
});

test("double validation returns the same visit", async () => {
  const scenario = await seedScenario();
  const first = await callApprove(scenario.merchant.token);
  const second = await callApprove(scenario.merchant.token);
  assert.equal(second.alreadyProcessed, true);
  assert.equal(second.visitId, first.visitId);
  assert.equal((await db.collection("visits").get()).size, 1);
});

test("retry after a lost response is idempotent", async () => {
  const scenario = await seedScenario();
  await callApprove(scenario.merchant.token);
  const recovered = await callApprove(scenario.merchant.token);
  assert.equal(recovered.alreadyProcessed, true);
  assert.equal((await db.collection("businessOperations").get()).size, 1);
});

test("two concurrent validations create no duplicate", async () => {
  const scenario = await seedScenario();
  const results = await Promise.all([
    callApprove(scenario.merchant.token),
    callApprove(scenario.merchant.token),
  ]);
  assert.equal(new Set(results.map((result) => result.visitId)).size, 1);
  assert.equal((await db.collection("visits").get()).size, 1);
});

test("oncePerDay blocks a second check-in for the same customer", async () => {
  const scenario = await seedScenario();
  await callApprove(scenario.merchant.token);
  await db.doc("checkIns/checkin-2").set({
    customerId: scenario.customer.uid,
    restaurantId: scenario.restaurantId,
    status: "pending",
    requestedAt: Timestamp.now(),
    expiresAt: Timestamp.fromMillis(Date.now() + 600_000),
  });
  await rejectsWith(
    () => callApprove(scenario.merchant.token, "checkin-2"),
    "ALREADY_EXISTS",
    "visit-already-exists"
  );
});

test("onceEveryXHours enforces the configured interval", async () => {
  const scenario = await seedScenario({
    restaurant: { validationPolicy: "onceEveryXHours", minimumHoursBetweenVisits: 4 },
  });
  await db.doc("visits/previous").set({
    userId: scenario.customer.uid,
    restaurantId: scenario.restaurantId,
    timestamp: Timestamp.fromMillis(Date.now() - 60 * 60 * 1000),
    checkInId: "previous",
    operationId: "approveCheckIn:previous",
  });
  await rejectsWith(
    () => callApprove(scenario.merchant.token),
    "FAILED_PRECONDITION",
    "frequency-rule-conflict"
  );
});

test("perTransaction permits successive distinct check-ins", async () => {
  const scenario = await seedScenario({ restaurant: { validationPolicy: "perTransaction" } });
  await callApprove(scenario.merchant.token);
  await db.doc("checkIns/checkin-2").set({
    customerId: scenario.customer.uid,
    restaurantId: scenario.restaurantId,
    status: "pending",
    requestedAt: Timestamp.now(),
    expiresAt: Timestamp.fromMillis(Date.now() + 600_000),
  });
  await callApprove(scenario.merchant.token, "checkin-2");
  assert.equal((await db.collection("visits").get()).size, 2);
});

test("a check-in remains bound to its original customer", async () => {
  const scenario = await seedScenario();
  const otherCustomer = await createUser("customer-other");
  const result = await callApprove(scenario.merchant.token);
  const visit = (await db.doc(`visits/${result.visitId}`).get()).data();
  assert.equal(visit.userId, scenario.customer.uid);
  assert.notEqual(visit.userId, otherCustomer.uid);
});
