"use strict";

const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const PROJECT_ID = process.env.GCLOUD_PROJECT || "demo-loyalo-v2";
const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const FUNCTIONS_HOST = "127.0.0.1:5001";

process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;

const app = getApps()[0] || initializeApp({ projectId: PROJECT_ID });
const db = getFirestore(app);

async function clearEmulators() {
  await Promise.all([
    fetch(
      `http://${FIRESTORE_HOST}/emulator/v1/projects/${PROJECT_ID}` +
        "/databases/(default)/documents",
      { method: "DELETE" }
    ),
    fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
      method: "DELETE",
    }),
  ]);
}

async function createUser(uid, role = "client") {
  const email = `${uid}@loyalo.test`;
  const response = await fetch(
    `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password: "Test123!", returnSecureToken: true }),
    }
  );
  const body = await response.json();
  if (!response.ok) throw new Error(JSON.stringify(body));
  await db.collection("users").doc(body.localId).set({ email, role });
  return { uid: body.localId, token: body.idToken, email };
}

async function seedScenario(options = {}) {
  const merchant = await createUser(options.merchantUid || "merchant", "merchant");
  const customer = await createUser(options.customerUid || "customer", "client");
  const restaurantId = options.restaurantId || "restaurant-1";
  const checkInId = options.checkInId || "checkin-1";
  const now = Date.now();
  const restaurant = {
    ownerId: merchant.uid,
    active: true,
    name: "Loyalo Emulator Café",
    pointsPerVisit: 120,
    rewardThreshold: 10,
    rewardLabel: "Café offert",
    loyaltyProgramEnabled: true,
    loyaltyProgramType: "visits",
    validationPolicy: "oncePerDay",
    minimumHoursBetweenVisits: 4,
    timeZone: "Europe/Paris",
    ...(options.restaurant || {}),
  };
  await Promise.all([
    db.collection("restaurants").doc(restaurantId).set(restaurant),
    db.collection("merchants").doc(merchant.uid).set({ restaurantId }),
    db.collection("checkIns").doc(checkInId).set({
      customerId: customer.uid,
      restaurantId,
      status: "pending",
      requestedAt: Timestamp.fromMillis(now - 60_000),
      expiresAt: Timestamp.fromMillis(now + 10 * 60_000),
      ...(options.checkIn || {}),
    }),
  ]);
  return { merchant, customer, restaurantId, checkInId };
}

async function callApprove(token, checkInId = "checkin-1") {
  const response = await fetch(
    `http://${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1/approveCheckInSecure`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        data: { checkInId, operationId: `approveCheckIn:${checkInId}` },
      }),
    }
  );
  const body = await response.json();
  if (!response.ok || body.error) {
    const error = new Error(body.error?.message || `HTTP ${response.status}`);
    error.code = body.error?.status;
    error.details = body.error?.details;
    throw error;
  }
  return body.result;
}

async function callReject(token, checkInId = "checkin-1") {
  const response = await fetch(
    `http://${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1/rejectCheckInSecure`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({
        data: { checkInId, operationId: `rejectCheckIn:${checkInId}` },
      }),
    }
  );
  const body = await response.json();
  if (!response.ok || body.error) {
    const error = new Error(body.error?.message || `HTTP ${response.status}`);
    error.code = body.error?.status;
    error.details = body.error?.details;
    throw error;
  }
  return body.result;
}

module.exports = {
  PROJECT_ID,
  db,
  Timestamp,
  clearEmulators,
  createUser,
  seedScenario,
  callApprove,
  callReject,
};
