"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  collection,
} = require("firebase/firestore");
const { PROJECT_ID } = require("./emulator_helpers");

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, "../../../firestore.rules"), "utf8"),
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
      setDoc(doc(admin, "restaurants/restaurant-b"), {
        ownerId: "merchant-b",
        active: true,
        name: "Restaurant B",
      }),
      setDoc(doc(admin, "merchants/merchant-a"), { restaurantId: "restaurant-a" }),
      setDoc(doc(admin, "merchants/merchant-b"), { restaurantId: "restaurant-b" }),
      setDoc(doc(admin, "checkIns/checkin-a"), {
        customerId: "customer-a",
        restaurantId: "restaurant-a",
        status: "pending",
        requestedAt: new Date(),
        expiresAt: new Date(Date.now() + 60000),
      }),
      setDoc(doc(admin, "visits/visit-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
      }),
      setDoc(doc(admin, "rewards/reward-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
        restaurantName: "Restaurant A",
        label: "Café offert",
        expiresAt: new Date(Date.now() + 86400000),
        status: "available",
      }),
      setDoc(doc(admin, "referrals/referral-a"), {
        referrerId: "customer-a",
        referredUserId: "customer-b",
        status: "pending",
      }),
      setDoc(doc(admin, "referralCodes/VALIDCODE"), {
        userId: "customer-a",
      }),
      setDoc(doc(admin, "referralCodes/SELFCODE"), {
        userId: "customer-c",
      }),
      setDoc(doc(admin, "users/customer-a"), {
        name: "Customer A",
        email: "a@example.test",
        phone: "0102030405",
        referralCode: "VALIDCODE",
      }),
      setDoc(doc(admin, "users/customer-b"), {
        name: "Customer B",
        email: "b@example.test",
        phone: "0600000000",
        referralCode: "CODEB",
      }),
      setDoc(doc(admin, "restaurantCustomers/restaurant-a_customer-a"), {
        restaurantId: "restaurant-a",
        userId: "customer-a",
        updatedAt: new Date(),
      }),
      setDoc(doc(admin, "validationCodes/123456"), {
        userId: "customer-a",
        dateKey: "2026-11-02",
        expiresAt: new Date(Date.now() + 60000),
      }),
      setDoc(doc(admin, "rewardDefinitions/definition-a"), {
        restaurantId: "restaurant-a",
        label: "Café",
        thresholdVisits: 5,
        active: true,
      }),
      setDoc(doc(admin, "exclusiveOffers/offer-a"), {
        restaurantId: "restaurant-a",
        title: "Offre A",
        startsAt: new Date(Date.now() - 60000),
        endsAt: new Date(Date.now() + 60000),
        active: true,
      }),
      setDoc(doc(admin, "notifications/notification-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
        type: "visit_validated",
        title: "Visite validée",
        body: "Votre visite est confirmée",
        read: false,
        isRead: false,
      }),
      setDoc(doc(admin, "wishlist/favorite-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
      }),
      setDoc(doc(admin, "reviews/restaurant-a_customer-a"), {
        userId: "customer-a",
        restaurantId: "restaurant-a",
        userName: "Customer A",
        rating: 5,
        comment: "Très bien",
        createdAt: new Date(),
      }),
      setDoc(doc(admin, "businessOperations/private-operation"), {
        merchantId: "merchant-a",
        status: "completed",
      }),
      setDoc(doc(admin, "loyaltyTransactionLocks/private-lock"), {
        restaurantId: "restaurant-a",
      }),
    ]);
  });
});

const firestoreFor = (uid) => environment.authenticatedContext(uid).firestore();

test("customer can read own check-in but not another customer's", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "checkIns/checkin-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "checkIns/checkin-a")));
});

test("merchant can read only check-ins from the linked restaurant", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "checkIns/checkin-a")));
  await assertFails(getDoc(doc(firestoreFor("merchant-b"), "checkIns/checkin-a")));
});

test("customer can create a pending check-in only for self", async () => {
  const customer = firestoreFor("customer-a");
  await assertSucceeds(setDoc(doc(customer, "checkIns/own"), {
    customerId: "customer-a",
    restaurantId: "restaurant-a",
    status: "pending",
    requestedAt: new Date(),
    expiresAt: new Date(Date.now() + 60000),
  }));
  await assertFails(setDoc(doc(customer, "checkIns/forged"), {
    customerId: "customer-b",
    restaurantId: "restaurant-a",
    status: "pending",
    requestedAt: new Date(),
    expiresAt: new Date(Date.now() + 60000),
  }));
});

test("visit reads are isolated between customer and merchants", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "visits/visit-a")));
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "visits/visit-a")));
  await assertFails(getDoc(doc(firestoreFor("merchant-b"), "visits/visit-a")));
});

test("reward reads are isolated", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "rewards/reward-a")));
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "rewards/reward-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "rewards/reward-a")));
});

test("referral reads are limited to participants", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "referrals/referral-a")));
  await assertSucceeds(getDoc(doc(firestoreFor("customer-b"), "referrals/referral-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-c"), "referrals/referral-a")));
});

test("referral creation requires a real code and forbids self referral", async () => {
  const referred = firestoreFor("customer-b");
  await assertSucceeds(setDoc(doc(referred, "referrals/initial_customer-b"), {
    referrerId: "customer-a",
    referredUserId: "customer-b",
    referralCode: "VALIDCODE",
    name: "Customer B",
    status: "pending",
    pointsEarned: 0,
    invitedAt: new Date(),
  }));
  await assertFails(setDoc(doc(referred, "referrals/restaurant-a_customer-b"), {
    referrerId: "customer-a",
    referredUserId: "customer-b",
    referralCode: "INVALID",
    restaurantId: "restaurant-a",
    name: "Customer B",
    status: "pending",
    pointsEarned: 0,
    invitedAt: new Date(),
  }));
  const self = firestoreFor("customer-c");
  await assertFails(setDoc(doc(self, "referrals/initial_customer-c"), {
    referrerId: "customer-c",
    referredUserId: "customer-c",
    referralCode: "SELFCODE",
    name: "Customer C",
    status: "pending",
    pointsEarned: 0,
    invitedAt: new Date(),
  }));
});

test("clients and merchants cannot award referral points directly", async () => {
  await assertFails(updateDoc(
    doc(firestoreFor("customer-a"), "referrals/referral-a"),
    { status: "rewarded", pointsEarned: 500 }
  ));
  await assertFails(updateDoc(
    doc(firestoreFor("merchant-a"), "referrals/referral-a"),
    {
      restaurantId: "restaurant-a",
      status: "rewarded",
      pointsEarned: 500,
      completedAt: new Date(),
      rewardedAt: new Date(),
      updatedAt: new Date(),
    }
  ));
});

test("anonymous access is denied", async () => {
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonymous, "restaurants/restaurant-a")));
  await assertFails(getDocs(collection(anonymous, "visits")));
});

test("clients cannot write visits or rewards directly", async () => {
  const customer = firestoreFor("customer-a");
  await assertFails(setDoc(doc(customer, "visits/forged"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    timestamp: new Date(),
    checkInId: "checkin-a",
    operationId: "approveCheckIn:checkin-a",
  }));
  await assertFails(setDoc(doc(customer, "rewards/forged"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    status: "available",
  }));
});

test("collection queries do not bypass merchant isolation", async () => {
  await assertFails(getDocs(collection(firestoreFor("merchant-b"), "checkIns")));
  assert.ok(true);
});

test("user profiles are private and sensitive fields cannot be injected", async () => {
  const customerA = firestoreFor("customer-a");
  await assertSucceeds(getDoc(doc(customerA, "users/customer-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "users/customer-a")));
  await assertSucceeds(updateDoc(doc(customerA, "users/customer-a"), {
    phone: "0700000000",
  }));
  await assertFails(updateDoc(doc(customerA, "users/customer-a"), {
    points: 999999,
  }));
  await assertFails(updateDoc(doc(customerA, "users/customer-a"), {
    referralCode: "STOLEN",
  }));
  await assertFails(updateDoc(doc(firestoreFor("customer-b"), "users/customer-a"), {
    phone: "0000000000",
  }));
  await assertSucceeds(setDoc(doc(customerA, "users/customer-a/devices/phone"), {
    token: "token-a",
  }));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "users/customer-a/devices/phone")));
});

test("referral and validation codes remain owned by their creator", async () => {
  const customerA = firestoreFor("customer-a");
  await assertSucceeds(getDoc(doc(customerA, "referralCodes/VALIDCODE")));
  await assertFails(updateDoc(doc(firestoreFor("customer-b"), "referralCodes/VALIDCODE"), {
    updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(customerA, "referralCodes/VALIDCODE"), {
    userId: "customer-b",
  }));
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "validationCodes/123456")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "validationCodes/123456")));
  await assertFails(updateDoc(doc(firestoreFor("customer-b"), "validationCodes/123456"), {
    expiresAt: new Date(Date.now() + 120000),
  }));
  await assertFails(deleteDoc(doc(customerA, "validationCodes/123456")));
});

test("merchant documents and restaurants are isolated by ownership", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "merchants/merchant-a")));
  await assertFails(getDoc(doc(firestoreFor("merchant-b"), "merchants/merchant-a")));
  await assertSucceeds(updateDoc(doc(firestoreFor("merchant-a"), "restaurants/restaurant-a"), {
    name: "Restaurant A sécurisé",
  }));
  await assertFails(updateDoc(doc(firestoreFor("merchant-b"), "restaurants/restaurant-a"), {
    name: "Restaurant détourné",
  }));
  await assertFails(updateDoc(doc(firestoreFor("merchant-a"), "restaurants/restaurant-a"), {
    ownerId: "merchant-b",
  }));
  await assertFails(deleteDoc(doc(firestoreFor("merchant-a"), "restaurants/restaurant-a")));
});

test("restaurant customer links expose only the linked customer", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "restaurantCustomers/restaurant-a_customer-a")));
  await assertSucceeds(getDoc(doc(firestoreFor("merchant-a"), "restaurantCustomers/restaurant-a_customer-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "restaurantCustomers/restaurant-a_customer-a")));
  await assertFails(updateDoc(doc(firestoreFor("customer-a"), "restaurantCustomers/restaurant-a_customer-a"), {
    userId: "customer-b",
  }));
  await assertFails(deleteDoc(doc(firestoreFor("merchant-a"), "restaurantCustomers/restaurant-a_customer-a")));
});

test("legacy approval requires one atomic coherent visit and cannot rewrite a terminal check-in", async () => {
  const merchant = firestoreFor("merchant-a");
  await assertFails(updateDoc(doc(merchant, "checkIns/checkin-a"), {
    status: "approved",
    validatedAt: new Date(),
    validatedBy: "merchant-a",
    pointsAwarded: 999,
    visitId: "forged-visit",
    syncOperationId: "approveCheckIn:checkin-a",
  }));

  const batch = writeBatch(merchant);
  batch.set(doc(merchant, "visits/legacy-visit"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    timestamp: new Date(),
    checkInId: "checkin-a",
    operationId: "approveCheckIn:checkin-a",
  });
  batch.update(doc(merchant, "checkIns/checkin-a"), {
    status: "approved",
    validatedAt: new Date(),
    validatedBy: "merchant-a",
    pointsAwarded: 120,
    visitId: "legacy-visit",
    syncOperationId: "approveCheckIn:checkin-a",
  });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(merchant, "checkIns/checkin-a"), {
    status: "rejected",
    rejectedAt: new Date(),
    rejectedBy: "merchant-a",
    syncOperationId: "rejectCheckIn:checkin-a",
  }));
  await assertFails(deleteDoc(doc(merchant, "visits/legacy-visit")));
});

test("check-in rejection is isolated and concurrent terminal transitions produce one winner", async () => {
  const merchantA = firestoreFor("merchant-a");
  await assertFails(updateDoc(doc(firestoreFor("merchant-b"), "checkIns/checkin-a"), {
    status: "rejected",
    rejectedAt: new Date(),
    rejectedBy: "merchant-b",
    syncOperationId: "rejectCheckIn:checkin-a",
  }));
  const attempts = await Promise.allSettled([
    updateDoc(doc(merchantA, "checkIns/checkin-a"), {
      status: "rejected",
      rejectedAt: new Date(),
      rejectedBy: "merchant-a",
      syncOperationId: "rejectCheckIn:checkin-a",
    }),
    updateDoc(doc(merchantA, "checkIns/checkin-a"), {
      status: "expired",
    }),
  ]);
  assert.equal(attempts.filter((result) => result.status === "fulfilled").length, 1);
  await assertFails(deleteDoc(doc(merchantA, "checkIns/checkin-a")));
});

test("rewards are isolated and only the owning merchant can redeem once", async () => {
  const merchantA = firestoreFor("merchant-a");
  await assertFails(setDoc(doc(firestoreFor("merchant-b"), "rewards/forged"), {
    userId: "customer-a",
    restaurantId: "restaurant-a",
    status: "available",
  }));
  await assertSucceeds(updateDoc(doc(merchantA, "rewards/reward-a"), {
    status: "used",
    redeemedAt: new Date(),
    redeemedBy: "merchant-a",
  }));
  await assertFails(updateDoc(doc(merchantA, "rewards/reward-a"), {
    status: "available",
  }));
  await assertFails(deleteDoc(doc(merchantA, "rewards/reward-a")));
});

test("reward definitions and exclusive offers are controlled by their restaurant merchant", async () => {
  await assertSucceeds(updateDoc(doc(firestoreFor("merchant-a"), "rewardDefinitions/definition-a"), {
    active: false,
  }));
  await assertFails(updateDoc(doc(firestoreFor("merchant-b"), "rewardDefinitions/definition-a"), {
    active: true,
  }));
  await assertSucceeds(updateDoc(doc(firestoreFor("merchant-a"), "exclusiveOffers/offer-a"), {
    title: "Offre A mise à jour",
  }));
  await assertFails(updateDoc(doc(firestoreFor("merchant-b"), "exclusiveOffers/offer-a"), {
    title: "Offre détournée",
  }));
  await assertFails(deleteDoc(doc(firestoreFor("merchant-b"), "exclusiveOffers/offer-a")));
  await assertSucceeds(deleteDoc(doc(firestoreFor("merchant-a"), "exclusiveOffers/offer-a")));
});

test("notifications can only be read and acknowledged by their recipient", async () => {
  const customerA = firestoreFor("customer-a");
  await assertSucceeds(getDoc(doc(customerA, "notifications/notification-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "notifications/notification-a")));
  await assertSucceeds(updateDoc(doc(customerA, "notifications/notification-a"), {
    read: true,
    isRead: true,
    readAt: new Date(),
  }));
  await assertFails(updateDoc(doc(customerA, "notifications/notification-a"), {
    title: "Titre falsifié",
  }));
  await assertFails(deleteDoc(doc(customerA, "notifications/notification-a")));
});

test("wishlist entries are private and deletable only by their owner", async () => {
  await assertSucceeds(getDoc(doc(firestoreFor("customer-a"), "wishlist/favorite-a")));
  await assertFails(getDoc(doc(firestoreFor("customer-b"), "wishlist/favorite-a")));
  await assertFails(deleteDoc(doc(firestoreFor("customer-b"), "wishlist/favorite-a")));
  await assertSucceeds(deleteDoc(doc(firestoreFor("customer-a"), "wishlist/favorite-a")));
});

test("reviews accept only the author's bounded rating and immutable identity", async () => {
  const customerA = firestoreFor("customer-a");
  await assertSucceeds(getDoc(doc(customerA, "reviews/restaurant-a_customer-a")));
  await assertSucceeds(updateDoc(doc(customerA, "reviews/restaurant-a_customer-a"), {
    rating: 4,
    comment: "Toujours bien",
    createdAt: new Date(),
  }));
  await assertFails(updateDoc(doc(customerA, "reviews/restaurant-a_customer-a"), {
    rating: 99,
  }));
  await assertFails(updateDoc(doc(firestoreFor("customer-b"), "reviews/restaurant-a_customer-a"), {
    comment: "Falsifié",
  }));
  await assertFails(deleteDoc(doc(customerA, "reviews/restaurant-a_customer-a")));
});

test("server-only collections and unknown collections are closed", async () => {
  for (const path of [
    "businessOperations/private-operation",
    "loyaltyTransactionLocks/private-lock",
  ]) {
    await assertFails(getDoc(doc(firestoreFor("merchant-a"), path)));
    await assertFails(updateDoc(doc(firestoreFor("merchant-a"), path), { status: "forged" }));
    await assertFails(deleteDoc(doc(firestoreFor("merchant-a"), path)));
  }
  await assertFails(setDoc(doc(firestoreFor("customer-a"), "unknown/data"), {
    value: true,
  }));
});
