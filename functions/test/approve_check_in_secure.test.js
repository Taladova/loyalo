"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  createApproveCheckInSecure,
} = require("../src/approve_check_in_secure");
const {
  createRejectCheckInSecure,
} = require("../src/reject_check_in_secure");

const NOW = new Date("2026-10-28T14:00:00.000Z");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const FakeFieldValue = {
  serverTimestamp: () => ({ __serverTimestamp: true }),
};

class FakeDocumentSnapshot {
  constructor(ref, value) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = value !== undefined;
    this._value = value;
  }

  data() {
    return this._value;
  }
}

class FakeDocumentReference {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").at(-1);
  }
}

class FakeQuery {
  constructor(db, collection, filters = [], order = null) {
    this.db = db;
    this.collection = collection;
    this.filters = filters;
    this.order = order;
  }

  where(field, operator, value) {
    assert.equal(operator, "==");
    return new FakeQuery(this.db, this.collection, [
      ...this.filters,
      { field, value },
    ], this.order);
  }

  orderBy(field, direction) {
    return new FakeQuery(this.db, this.collection, this.filters, {
      field,
      direction,
    });
  }
}

class FakeCollectionReference extends FakeQuery {
  constructor(db, collection) {
    super(db, collection);
  }

  doc(id) {
    return new FakeDocumentReference(this.db, `${this.collection}/${id}`);
  }
}

class FakeTransaction {
  constructor(db) {
    this.db = db;
    this.writes = [];
  }

  async get(target) {
    if (target instanceof FakeDocumentReference) {
      return new FakeDocumentSnapshot(target, this.db.documents.get(target.path));
    }
    const prefix = `${target.collection}/`;
    let docs = [...this.db.documents.entries()]
      .filter(([path]) => path.startsWith(prefix))
      .map(([path, value]) => ({
        ref: new FakeDocumentReference(this.db, path),
        value,
      }))
      .filter(({ value }) =>
        target.filters.every(({ field, value: expected }) =>
          value[field] === expected
        )
      );
    if (target.order) {
      const multiplier = target.order.direction === "desc" ? -1 : 1;
      docs.sort((left, right) => {
        const a = toMillis(left.value[target.order.field]);
        const b = toMillis(right.value[target.order.field]);
        return (a - b) * multiplier;
      });
    }
    return {
      docs: docs.map(
        ({ ref, value }) => new FakeDocumentSnapshot(ref, value)
      ),
    };
  }

  create(ref, data) {
    this.writes.push({ type: "create", ref, data });
  }

  set(ref, data, options) {
    this.writes.push({ type: "set", ref, data, options });
  }

  update(ref, data) {
    this.writes.push({ type: "update", ref, data });
  }

  commit() {
    for (const write of this.writes) {
      const current = this.db.documents.get(write.ref.path);
      if (write.type === "create" && current !== undefined) {
        const error = new Error("already exists");
        error.code = 6;
        throw error;
      }
      if (write.type === "update" && current === undefined) {
        const error = new Error("not found");
        error.code = 5;
        throw error;
      }
      const resolved = resolveServerTimestamps(write.data, this.db.now);
      if (write.type === "update" || write.options?.merge) {
        this.db.documents.set(write.ref.path, { ...current, ...resolved });
      } else {
        this.db.documents.set(write.ref.path, resolved);
      }
    }
  }
}

class FakeFirestore {
  constructor(now = NOW) {
    this.documents = new Map();
    this.now = now;
    this._queue = Promise.resolve();
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  seed(path, data) {
    this.documents.set(path, data);
    return this;
  }

  data(path) {
    return this.documents.get(path);
  }

  count(collection) {
    const prefix = `${collection}/`;
    return [...this.documents.keys()].filter((path) => path.startsWith(prefix))
      .length;
  }

  runTransaction(callback) {
    const run = async () => {
      const transaction = new FakeTransaction(this);
      const result = await callback(transaction);
      transaction.commit();
      return result;
    };
    const result = this._queue.then(run, run);
    this._queue = result.catch(() => {});
    return result;
  }
}

function resolveServerTimestamps(value, now) {
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [
      key,
      item && item.__serverTimestamp === true ? new Date(now) : item,
    ])
  );
}

function toMillis(value) {
  if (value instanceof Date) return value.getTime();
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  return 0;
}

function baseDatabase(overrides = {}) {
  const db = new FakeFirestore();
  db.seed("merchants/merchant-1", { restaurantId: "restaurant-1" });
  db.seed("restaurants/restaurant-1", {
    ownerId: "merchant-1",
    active: true,
    name: "Loyalo Café",
    pointsPerVisit: 120,
    rewardThreshold: 10,
    rewardLabel: "Café offert",
    loyaltyProgramEnabled: true,
    loyaltyProgramType: "visits",
    validationPolicy: "oncePerDay",
    minimumHoursBetweenVisits: 4,
    timeZone: "Europe/Paris",
    ...overrides.restaurant,
  });
  db.seed("checkIns/checkin-1", {
    customerId: "customer-1",
    restaurantId: "restaurant-1",
    status: "pending",
    requestedAt: new Date("2026-10-28T13:55:00.000Z"),
    expiresAt: new Date("2026-10-28T14:10:00.000Z"),
    ...overrides.checkIn,
  });
  return db;
}

function handler(db) {
  return createApproveCheckInSecure({
    db,
    FieldValue: FakeFieldValue,
    HttpsError: FakeHttpsError,
    clock: () => new Date(NOW),
  });
}

function rejectHandler(db) {
  return createRejectCheckInSecure({
    db,
    FieldValue: FakeFieldValue,
    HttpsError: FakeHttpsError,
  });
}

function request(data = {}, uid = "merchant-1") {
  return {
    auth: uid ? { uid } : null,
    data: {
      checkInId: "checkin-1",
      operationId: "approveCheckIn:checkin-1",
      ...data,
    },
  };
}

function rejectRequest(data = {}, uid = "merchant-1") {
  return {
    auth: uid ? { uid } : null,
    data: {
      checkInId: "checkin-1",
      operationId: "rejectCheckIn:checkin-1",
      ...data,
    },
  };
}

async function expectError(promise, code, reason) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code);
    if (reason) assert.equal(error.details?.reason, reason);
    return true;
  });
}

function seedVisit(db, id, timestamp = new Date("2026-10-27T12:00:00Z")) {
  db.seed(`visits/${id}`, {
    userId: "customer-1",
    restaurantId: "restaurant-1",
    timestamp,
    checkInId: `old-${id}`,
    operationId: `approveCheckIn:old-${id}`,
  });
}

test("1. authorized merchant approves the check-in", async () => {
  const result = await handler(baseDatabase())(request());
  assert.equal(result.success, true);
  assert.equal(result.status, "approved");
});

test("2. unauthenticated user is rejected", async () => {
  await expectError(handler(baseDatabase())(request({}, null)), "unauthenticated");
});

test("3. client cannot approve a check-in", async () => {
  await expectError(
    handler(baseDatabase())(request({}, "customer-1")),
    "permission-denied"
  );
});

test("4. merchant from another restaurant is rejected", async () => {
  const db = baseDatabase().seed("merchants/merchant-2", {
    restaurantId: "restaurant-2",
  });
  await expectError(
    handler(db)(request({}, "merchant-2")),
    "permission-denied"
  );
});

test("5. missing check-in returns not-found", async () => {
  const db = baseDatabase();
  db.documents.delete("checkIns/checkin-1");
  await expectError(handler(db)(request()), "not-found");
});

test("6. expired check-in is rejected using server time", async () => {
  const db = baseDatabase({
    checkIn: { expiresAt: new Date("2026-10-28T13:59:59Z") },
  });
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "check-in-expired"
  );
});

test("7. rejected check-in cannot be approved", async () => {
  const db = baseDatabase({ checkIn: { status: "rejected" } });
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "check-in-rejected"
  );
});

test("8. first approval creates a confirmed visit", async () => {
  const db = baseDatabase();
  const result = await handler(db)(request());
  assert.equal(db.data(`visits/${result.visitId}`).checkInId, "checkin-1");
  assert.equal(db.data("checkIns/checkin-1").visitId, result.visitId);
});

test("9. same operation replay returns the stored result", async () => {
  const db = baseDatabase();
  await handler(db)(request());
  const replay = await handler(db)(request());
  assert.equal(replay.alreadyProcessed, true);
  assert.equal(db.count("visits"), 1);
});

test("10. a different operation id for the same check-in is invalid", async () => {
  await expectError(
    handler(baseDatabase())(
      request({ operationId: "approveCheckIn:different" })
    ),
    "invalid-argument"
  );
});

test("11. concurrent calls resolve to one logical operation", async () => {
  const db = baseDatabase();
  const approve = handler(db);
  const [first, second] = await Promise.all([approve(request()), approve(request())]);
  assert.equal([first, second].filter((item) => item.alreadyProcessed).length, 1);
});

test("12. concurrent calls create exactly one visit", async () => {
  const db = baseDatabase();
  const approve = handler(db);
  await Promise.all([approve(request()), approve(request())]);
  assert.equal(db.count("visits"), 1);
});

test("13. points are read from the restaurant configuration", async () => {
  const db = baseDatabase({ restaurant: { pointsPerVisit: 275 } });
  const result = await handler(db)(request());
  assert.equal(result.pointsAwarded, 275);
  assert.equal(db.data("checkIns/checkin-1").pointsAwarded, 275);
});

test("14. oncePerDay rejects a second confirmed visit", async () => {
  const db = baseDatabase();
  seedVisit(db, "today", new Date("2026-10-28T08:00:00Z"));
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "frequency-rule-conflict"
  );
});

test("15. onceEveryXHours enforces the rolling interval", async () => {
  const db = baseDatabase({
    restaurant: {
      validationPolicy: "onceEveryXHours",
      minimumHoursBetweenVisits: 4,
    },
  });
  seedVisit(db, "recent", new Date("2026-10-28T12:00:00Z"));
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "frequency-rule-conflict"
  );
});

test("16. perTransaction accepts a recent previous visit", async () => {
  const db = baseDatabase({
    restaurant: { validationPolicy: "perTransaction" },
  });
  seedVisit(db, "recent", new Date("2026-10-28T13:59:00Z"));
  const result = await handler(db)(request());
  assert.equal(result.status, "approved");
  assert.equal(db.count("visits"), 2);
});

test("17. reward is created once with a deterministic id", async () => {
  const db = baseDatabase({ restaurant: { rewardThreshold: 1 } });
  const result = await handler(db)(request());
  assert.equal(result.rewardId, "restaurant-1_customer-1_cycle_1");
  const replay = await handler(db)(request());
  assert.equal(replay.rewardId, result.rewardId);
  assert.equal(db.count("rewards"), 1);
});

test("18. an already used reward is never reactivated", async () => {
  const db = baseDatabase({ restaurant: { rewardThreshold: 1 } });
  db.seed("rewards/restaurant-1_customer-1_cycle_1", {
    userId: "customer-1",
    restaurantId: "restaurant-1",
    status: "used",
    cycle: 1,
  });
  await handler(db)(request());
  assert.equal(
    db.data("rewards/restaurant-1_customer-1_cycle_1").status,
    "used"
  );
});

test("19. notification uses a deterministic document id", async () => {
  const db = baseDatabase();
  await handler(db)(request());
  await handler(db)(request());
  assert.equal(db.count("notifications"), 1);
  assert.equal(
    db.data("notifications/checkin-sync-checkin-1").relatedId,
    "checkin-1"
  );
});

test("20. a lost response can be retried without duplicate effects", async () => {
  const db = baseDatabase({ restaurant: { rewardThreshold: 1 } });
  await handler(db)(request());
  const recovered = await handler(db)(request());
  assert.equal(recovered.alreadyProcessed, true);
  assert.equal(db.count("visits"), 1);
  assert.equal(db.count("rewards"), 1);
  assert.equal(db.count("notifications"), 1);
});

test("unexpected fields are rejected", async () => {
  await expectError(
    handler(baseDatabase())(request({ pointsAwarded: 99999 })),
    "invalid-argument"
  );
});

test("inactive restaurant cannot approve a check-in", async () => {
  const db = baseDatabase({ restaurant: { active: false } });
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "restaurant-inactive"
  );
});

test("21. authorized merchant rejects without creating loyalty data", async () => {
  const db = baseDatabase();
  const result = await rejectHandler(db)(rejectRequest());
  assert.equal(result.status, "rejected");
  assert.equal(db.data("checkIns/checkin-1").rejectedBy, "merchant-1");
  assert.equal(db.count("visits"), 0);
  assert.equal(db.count("rewards"), 0);
});

test("22. client and other merchant cannot reject", async () => {
  await expectError(
    rejectHandler(baseDatabase())(rejectRequest({}, "customer-1")),
    "permission-denied"
  );
  const db = baseDatabase().seed("merchants/merchant-2", {
    restaurantId: "restaurant-2",
  });
  await expectError(
    rejectHandler(db)(rejectRequest({}, "merchant-2")),
    "permission-denied"
  );
});

test("23. same rejection operation is idempotent", async () => {
  const db = baseDatabase();
  await rejectHandler(db)(rejectRequest());
  const replay = await rejectHandler(db)(rejectRequest());
  assert.equal(replay.alreadyProcessed, true);
  assert.equal(db.count("businessOperations"), 1);
});

test("24. concurrent rejections produce one logical operation", async () => {
  const db = baseDatabase();
  const [first, second] = await Promise.all([
    rejectHandler(db)(rejectRequest()),
    rejectHandler(db)(rejectRequest()),
  ]);
  assert.equal(first.status, "rejected");
  assert.equal(second.alreadyProcessed, true);
  assert.equal(db.count("businessOperations"), 1);
});

test("25. rejection after approval is blocked", async () => {
  const db = baseDatabase();
  await handler(db)(request());
  await expectError(
    rejectHandler(db)(rejectRequest()),
    "failed-precondition",
    "check-in-approved"
  );
});

test("26. approval after rejection is blocked", async () => {
  const db = baseDatabase();
  await rejectHandler(db)(rejectRequest());
  await expectError(
    handler(db)(request()),
    "failed-precondition",
    "check-in-rejected"
  );
});

test("27. rejection input cannot inject merchant identifiers", async () => {
  await expectError(
    rejectHandler(baseDatabase())(
      rejectRequest({ restaurantId: "restaurant-2" })
    ),
    "invalid-argument"
  );
});

test("28. first confirmed visit rewards a valid referral once", async () => {
  const db = baseDatabase().seed("referrals/initial_customer-1", {
    referrerId: "referrer-1",
    referredUserId: "customer-1",
    name: "Sophie",
    status: "pending",
    pointsEarned: 0,
  });
  const result = await handler(db)(request());
  const referral = db.data("referrals/initial_customer-1");
  assert.equal(referral.status, "rewarded");
  assert.equal(referral.pointsEarned, 500);
  assert.deepEqual(result.referralRewardIds, ["initial_customer-1"]);
  assert.equal(db.count("notifications"), 2);

  const replay = await handler(db)(request());
  assert.deepEqual(replay.referralRewardIds, ["initial_customer-1"]);
  assert.equal(db.count("notifications"), 2);
});

test("29. second confirmed visit does not reward a pending referral", async () => {
  const db = baseDatabase().seed("referrals/initial_customer-1", {
    referrerId: "referrer-1",
    referredUserId: "customer-1",
    name: "Sophie",
    status: "pending",
    pointsEarned: 0,
  });
  seedVisit(db, "previous", new Date("2026-10-27T12:00:00Z"));
  await handler(db)(request());
  assert.equal(db.data("referrals/initial_customer-1").status, "pending");
});

test("30. rewarded, missing and self referrals create no second bonus", async () => {
  const rewarded = baseDatabase().seed("referrals/initial_customer-1", {
    referrerId: "referrer-1",
    referredUserId: "customer-1",
    status: "rewarded",
    pointsEarned: 500,
  });
  await handler(rewarded)(request());
  assert.equal(
    rewarded.data("referrals/initial_customer-1").pointsEarned,
    500
  );

  const self = baseDatabase().seed("referrals/initial_customer-1", {
    referrerId: "customer-1",
    referredUserId: "customer-1",
    status: "pending",
    pointsEarned: 0,
  });
  await handler(self)(request());
  assert.equal(self.data("referrals/initial_customer-1").status, "pending");

  const missing = baseDatabase();
  const result = await handler(missing)(request());
  assert.deepEqual(result.referralRewardIds, []);
});

test("31. rejected or expired check-in never rewards referral", async () => {
  for (const checkIn of [
    { status: "rejected" },
    { expiresAt: new Date("2026-10-28T13:59:59Z") },
  ]) {
    const db = baseDatabase({ checkIn }).seed(
      "referrals/initial_customer-1",
      {
        referrerId: "referrer-1",
        referredUserId: "customer-1",
        status: "pending",
        pointsEarned: 0,
      }
    );
    await assert.rejects(handler(db)(request()));
    assert.equal(db.data("referrals/initial_customer-1").status, "pending");
  }
});

test("32. concurrent approval creates one referral bonus", async () => {
  const db = baseDatabase().seed("referrals/initial_customer-1", {
    referrerId: "referrer-1",
    referredUserId: "customer-1",
    name: "Sophie",
    status: "pending",
    pointsEarned: 0,
  });
  await Promise.all([handler(db)(request()), handler(db)(request())]);
  assert.equal(db.data("referrals/initial_customer-1").pointsEarned, 500);
  assert.equal(
    db.count("notifications"),
    2,
    "one visit notification and one referral notification"
  );
});
