"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { doc, collection, getDoc, getDocs, query, where, setDoc, setLogLevel } = require("firebase/firestore");

test("client search respects the existing Pilot directory permissions", { skip: !process.env.FIRESTORE_EMULATOR_HOST }, async (t) => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.match(endpoint, /^(127\.0\.0\.1|localhost):\d+$/);
  const [host, port] = endpoint.split(":");
  const environment = await initializeTestEnvironment({
    projectId: "demo-loyalo-client-search-ui08",
    firestore: { host, port: Number(port),
      rules: fs.readFileSync(path.resolve(__dirname, "../../../config/firebase/pilot/firestore.rules"), "utf8") },
  });
  t.after(() => environment.cleanup());
  await environment.clearFirestore();
  setLogLevel("silent");
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchants", "search-owner"), { restaurantId: "search-shop" });
    await setDoc(doc(db, "merchants", "foreign-owner"), { restaurantId: "foreign-shop" });
    for (const suffix of ["own", "foreign", "unlinked"]) {
      await setDoc(doc(db, "users", `client-${suffix}`), {
        name: "Nom local identique", phone: "+33 6 11 22 33 44", email: `${suffix}@local.example`,
      });
    }
    await setDoc(doc(db, "restaurantCustomers", "search-shop_client-own"), {
      restaurantId: "search-shop", userId: "client-own",
    });
    await setDoc(doc(db, "restaurantCustomers", "foreign-shop_client-foreign"), {
      restaurantId: "foreign-shop", userId: "client-foreign",
    });
  });
  const merchant = environment.authenticatedContext("search-owner").firestore();
  const foreign = environment.authenticatedContext("foreign-owner").firestore();

  await t.test("the merchant can read an individually associated profile", async () => {
    const own = await assertSucceeds(getDoc(doc(merchant, "users", "client-own")));
    assert.equal(own.data().name, "Nom local identique");
    assert.equal(own.data().email, "own@local.example");
  });
  await t.test("identical names and phone numbers do not grant access to other profiles", async () => {
    await assertFails(getDoc(doc(merchant, "users", "client-foreign")));
    await assertFails(getDoc(doc(merchant, "users", "client-unlinked")));
    await assertFails(getDoc(doc(foreign, "users", "client-own")));
  });
  await t.test("global and filtered account searches remain forbidden", async () => {
    await assertFails(getDocs(collection(merchant, "users")));
    await assertFails(getDocs(query(collection(merchant, "users"), where("name", "==", "Nom local identique"))));
    await assertFails(getDocs(query(collection(merchant, "users"), where("phone", "==", "+33 6 11 22 33 44"))));
    await assertFails(getDocs(query(collection(merchant, "users"), where("email", "==", "own@local.example"))));
  });
  await t.test("a missing session cannot read merchant directory profiles", async () => {
    const anonymous = environment.unauthenticatedContext().firestore();
    const unrelated = environment.authenticatedContext("unrelated-account").firestore();
    await assertFails(getDoc(doc(anonymous, "users", "client-own")));
    await assertFails(getDoc(doc(unrelated, "users", "client-own")));
  });
});
