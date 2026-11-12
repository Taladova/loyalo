"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, collection, getDoc, getDocs, query, where, setDoc, updateDoc, Timestamp, setLogLevel } = require("firebase/firestore");

test("dashboard preserves merchant isolation under unchanged Pilot rules", { skip: !process.env.FIRESTORE_EMULATOR_HOST }, async (t) => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(endpoint, /^(127\.0\.0\.1|localhost):\d+$/);
  const [host, port] = endpoint.split(":");
  const environment = await initializeTestEnvironment({
    projectId: "demo-loyalo-dashboard-ui07",
    firestore: {
      host, port: Number(port),
      rules: fs.readFileSync(path.resolve(__dirname, "../../../config/firebase/pilot/firestore.rules"), "utf8"),
    },
  });
  t.after(() => environment.cleanup());
  await environment.clearFirestore();
  setLogLevel("silent");
  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const suffix of ["one", "two"]) {
      await setDoc(doc(db, "merchants", `merchant-${suffix}`), { restaurantId: `shop-${suffix}` });
      await setDoc(doc(db, "restaurants", `shop-${suffix}`), {
        ownerId: `merchant-${suffix}`, active: true, status: "active",
        name: `Local fixture ${suffix}`, cuisine: "Café", rewardThreshold: 10, rewardLabel: "Un café",
      });
      await setDoc(doc(db, "users", `customer-${suffix}`), { name: `Client ${suffix}` });
      await setDoc(doc(db, "restaurantCustomers", `shop-${suffix}_customer-${suffix}`), {
        restaurantId: `shop-${suffix}`, userId: `customer-${suffix}`,
      });
      await setDoc(doc(db, "visits", `visit-${suffix}`), {
        restaurantId: `shop-${suffix}`, userId: `customer-${suffix}`, timestamp: Timestamp.fromDate(yesterday),
      });
      await setDoc(doc(db, "checkIns", `arrival-${suffix}`), {
        restaurantId: `shop-${suffix}`, customerId: `customer-${suffix}`, status: "pending",
        requestedAt: Timestamp.fromDate(now), expiresAt: Timestamp.fromMillis(now.getTime() + 600000),
      });
      await setDoc(doc(db, "rewards", `reward-${suffix}`), {
        restaurantId: `shop-${suffix}`, userId: `customer-${suffix}`, status: "available",
      });
      await setDoc(doc(db, "exclusiveOffers", `offer-${suffix}`), { restaurantId: `shop-${suffix}`, active: false });
    }
  });
  const merchant = environment.authenticatedContext("merchant-one").firestore();
  const client = environment.authenticatedContext("customer-one").firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const scoped = (db, name, id) => query(collection(db, name), where("restaurantId", "==", id));

  await t.test("period statistics read only this merchant's confirmed visits", async () => {
    for (const days of [1, 7, 30]) {
      const rows = await assertSucceeds(getDocs(query(scoped(merchant, "visits", "shop-one"),
        where("timestamp", ">=", Timestamp.fromMillis(now.getTime() - days * 86400000)),
        where("timestamp", "<=", Timestamp.fromDate(now)))));
      assert.equal(rows.size, 1);
      assert.equal(rows.docs[0].data().restaurantId, "shop-one");
    }
    await assertFails(getDocs(scoped(merchant, "visits", "shop-two")));
    await assertFails(getDocs(collection(merchant, "visits")));
    await assertFails(getDocs(scoped(anonymous, "visits", "shop-one")));
  });

  await t.test("Express queue cannot read or reject another merchant's arrival", async () => {
    const own = await assertSucceeds(getDocs(scoped(merchant, "checkIns", "shop-one")));
    assert.deepEqual(own.docs.map((item) => item.id), ["arrival-one"]);
    await assertFails(getDocs(scoped(merchant, "checkIns", "shop-two")));
    await assertFails(getDoc(doc(merchant, "checkIns", "arrival-two")));
    await assertFails(updateDoc(doc(merchant, "checkIns", "arrival-two"), {
      status: "rejected", rejectedBy: "merchant-one", rejectedAt: Timestamp.fromDate(now),
    }));
  });

  await t.test("client names remain limited to the existing restaurant directory", async () => {
    assert.equal((await assertSucceeds(getDoc(doc(merchant, "users", "customer-one")))).data().name, "Client one");
    await assertFails(getDoc(doc(merchant, "users", "customer-two")));
    await assertFails(getDocs(collection(merchant, "users")));
  });

  await t.test("quick-action data keeps the existing offer and reward scope", async () => {
    assert.equal((await assertSucceeds(getDocs(scoped(merchant, "rewards", "shop-one")))).size, 1);
    await assertFails(getDocs(scoped(merchant, "rewards", "shop-two")));
    assert.equal((await assertSucceeds(getDocs(scoped(merchant, "exclusiveOffers", "shop-one")))).size, 1);
    await assertFails(getDoc(doc(merchant, "exclusiveOffers", "offer-two")));
  });

  await t.test("dashboard clients cannot bypass trusted visit and reward creation", async () => {
    for (const db of [merchant, client]) {
      for (const name of ["visits", "rewards"]) {
        await assertFails(setDoc(doc(db, name, "forbidden-ui-write"), {
          restaurantId: "shop-one", userId: "customer-one", timestamp: Timestamp.fromDate(now),
        }));
      }
    }
  });
});
