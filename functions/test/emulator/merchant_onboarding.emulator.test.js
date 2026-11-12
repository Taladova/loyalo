"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, collection, getDoc, getDocs, query, where, setDoc, runTransaction, setLogLevel } = require("firebase/firestore");

test("merchant onboarding respects unchanged Pilot rules", { skip: !process.env.FIRESTORE_EMULATOR_HOST }, async (t) => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(endpoint, /^(127\.0\.0\.1|localhost):\d+$/);
  const [host, port] = endpoint.split(":");
  const environment = await initializeTestEnvironment({
    projectId: "demo-loyalo-onboarding-ui05",
    firestore: {
      host, port: Number(port),
      rules: fs.readFileSync(path.resolve(__dirname, "../../../config/firebase/pilot/firestore.rules"), "utf8"),
    },
  });
  t.after(() => environment.cleanup());
  await environment.clearFirestore();
  setLogLevel("silent");
  const ownerId = "merchant-onboarding";
  const id = `merchant_${ownerId}`;
  const owner = environment.authenticatedContext(ownerId).firestore();
  const client = environment.authenticatedContext("client-onboarding").firestore();
  const other = environment.authenticatedContext("other-merchant").firestore();
  const restaurantRef = doc(owner, "restaurants", id);
  const merchantRef = doc(owner, "merchants", ownerId);
  const draft = {
    ownerId, name: "Commerce en brouillon", cuisine: "Caviste",
    category: "Caviste", email: "merchant@example.org",
    rewardThreshold: 10, rewardLabel: "", pointsPerVisit: 350,
    loyaltyProgramType: "visits", loyaltyProgramEnabled: false,
    active: false, status: "draft",
  };

  await t.test("draft creation, owner query and sequential role link are allowed", async () => {
    assert.equal((await assertSucceeds(getDoc(merchantRef))).exists(), false);
    assert.equal((await assertSucceeds(getDocs(query(collection(owner, "restaurants"), where("ownerId", "==", ownerId))))).size, 0);
    await assertSucceeds(runTransaction(owner, async (transaction) => {
      const link = await transaction.get(merchantRef);
      assert.equal(link.exists(), false);
      transaction.set(restaurantRef, draft);
    }));
    await assertSucceeds(runTransaction(owner, async (transaction) => {
      await transaction.get(merchantRef);
      assert.equal((await transaction.get(restaurantRef)).data().ownerId, ownerId);
      transaction.set(merchantRef, { restaurantId: id });
    }));
    assert.equal((await getDoc(merchantRef)).data().restaurantId, id);
  });

  await t.test("draft remains private and another merchant cannot claim it", async () => {
    await assertFails(getDoc(doc(client, "restaurants", id)));
    assert.equal((await assertSucceeds(getDocs(query(collection(client, "restaurants"), where("active", "==", true))))).size, 0);
    await assertFails(setDoc(doc(other, "merchants", "other-merchant"), { restaurantId: id }));
    await assertFails(setDoc(doc(client, "visits", "forbidden-visit"), { restaurantId: id, userId: "client-onboarding" }));
    await assertFails(setDoc(doc(client, "rewards", "forbidden-reward"), { restaurantId: id, userId: "client-onboarding" }));
  });

  await t.test("required compatibility fields cannot be omitted", async () => {
    const { rewardThreshold, rewardLabel, ...incomplete } = draft;
    void rewardThreshold; void rewardLabel;
    await assertFails(setDoc(doc(owner, "restaurants", "incomplete-commerce"), incomplete));
  });

  await t.test("publication and valid configuration are committed together", async () => {
    await assertSucceeds(runTransaction(owner, async (transaction) => {
      const snapshot = await transaction.get(restaurantRef);
      assert.equal(snapshot.data().active, false);
      transaction.update(restaurantRef, {
        active: true, status: "active", loyaltyProgramEnabled: true,
        rewardThreshold: 5, rewardLabel: "Une dégustation", pointsPerVisit: 100,
      });
    }));
    const published = (await assertSucceeds(getDoc(doc(client, "restaurants", id)))).data();
    assert.equal(published.active, true);
    assert.equal(published.loyaltyProgramEnabled, true);
    assert.equal(published.rewardLabel, "Une dégustation");
    assert.equal(published.ownerId, ownerId);
    assert.equal((await getDoc(merchantRef)).data().restaurantId, id);
  });
});
