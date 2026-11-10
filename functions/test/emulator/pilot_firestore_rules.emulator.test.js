"use strict";

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, updateDoc } = require("firebase/firestore");
const { PROJECT_ID } = require("./emulator_helpers");

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(
        path.join(__dirname, "../../../config/firebase/pilot/firestore.rules"),
        "utf8"
      ),
    },
  });
});
test.after(async () => environment.cleanup());

test.beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await Promise.all([
      setDoc(doc(admin, "restaurants/restaurant-a"), {
        ownerId: "merchant-a",
        active: true,
        name: "Restaurant A",
        pointsPerVisit: 120,
      }),
      setDoc(doc(admin, "merchants/merchant-a"), {
        restaurantId: "restaurant-a",
      }),
      setDoc(doc(admin, "checkIns/checkin-a"), {
        customerId: "customer-a",
        restaurantId: "restaurant-a",
        status: "pending",
        requestedAt: new Date(),
        expiresAt: new Date(Date.now() + 60000),
      }),
      setDoc(doc(admin, "rewards/reward-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
        restaurantName: "Restaurant A",
        label: "Café offert",
        expiresAt: new Date(Date.now() + 86400000),
        status: "available",
      }),
    ]);
  });
});

const firestoreFor = (uid) =>
  environment.authenticatedContext(uid).firestore();

test("pilot blocks direct merchant approval and rejection", async () => {
  const checkIn = doc(firestoreFor("merchant-a"), "checkIns/checkin-a");

  await assertFails(updateDoc(checkIn, {
    status: "approved",
    validatedAt: new Date(),
    validatedBy: "merchant-a",
    pointsAwarded: 120,
    visitId: "visit-a",
    syncOperationId: "approveCheckIn:checkin-a",
  }));
  await assertFails(updateDoc(checkIn, {
    status: "rejected",
    rejectedAt: new Date(),
    rejectedBy: "merchant-a",
    syncOperationId: "rejectCheckIn:checkin-a",
  }));
});

test("pilot blocks direct visit and business reward creation", async () => {
  const merchant = firestoreFor("merchant-a");

  await assertFails(setDoc(doc(merchant, "visits/visit-forged"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    timestamp: new Date(),
    checkInId: "checkin-a",
    operationId: "approveCheckIn:checkin-a",
  }));
  await assertFails(setDoc(doc(merchant, "rewards/reward-forged"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    restaurantName: "Restaurant A",
    label: "Récompense arbitraire",
    expiresAt: new Date(Date.now() + 86400000),
    status: "available",
  }));
});

test("pilot preserves legitimate customer check-in cancellation", async () => {
  const customer = firestoreFor("customer-a");
  const ownCheckIn = doc(customer, "checkIns/checkin-customer");

  await assertSucceeds(setDoc(ownCheckIn, {
    customerId: "customer-a",
    restaurantId: "restaurant-a",
    requestedAt: new Date(),
    expiresAt: new Date(Date.now() + 60000),
    status: "pending",
  }));
  await assertSucceeds(updateDoc(ownCheckIn, {
    status: "cancelled",
    cancelledAt: new Date(),
  }));
});

test("pilot preserves merchant redemption of a server-created reward", async () => {
  await assertSucceeds(updateDoc(
    doc(firestoreFor("merchant-a"), "rewards/reward-a"),
    {
      status: "used",
      redeemedAt: new Date(),
      redeemedBy: "merchant-a",
    }
  ));
});
