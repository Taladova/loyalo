"use strict";

const DEFAULT_TIME_ZONE = "Europe/Paris";
const MAX_ID_LENGTH = 128;
const REFERRAL_BONUS_POINTS = 500;
const ALLOWED_INPUT_KEYS = new Set(["checkInId", "operationId"]);

function createApproveCheckInSecure({ db, FieldValue, HttpsError, clock }) {
  if (!db || !FieldValue || !HttpsError) {
    throw new TypeError("Missing approveCheckInSecure dependency");
  }
  const serverClock = clock || (() => new Date());

  return async function approveCheckInSecure(request) {
    const uid = request && request.auth && request.auth.uid;
    if (typeof uid !== "string" || uid.length === 0) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const { checkInId, operationId } = validateInput(
      request && request.data,
      HttpsError
    );
    const receivedAt = serverClock();
    if (!(receivedAt instanceof Date) || Number.isNaN(receivedAt.getTime())) {
      throw new HttpsError("internal", "Server clock unavailable.");
    }

    try {
      return await db.runTransaction(async (transaction) => {
        const merchantRef = db.collection("merchants").doc(uid);
        const checkInRef = db.collection("checkIns").doc(checkInId);
        const operationRef = db
          .collection("businessOperations")
          .doc(operationId);

        const [merchantSnapshot, checkInSnapshot, operationSnapshot] =
          await Promise.all([
            transaction.get(merchantRef),
            transaction.get(checkInRef),
            transaction.get(operationRef),
          ]);

        if (!merchantSnapshot.exists) {
          throw new HttpsError(
            "permission-denied",
            "Merchant access required."
          );
        }
        if (!checkInSnapshot.exists) {
          throw new HttpsError("not-found", "Check-in not found.");
        }

        const merchant = merchantSnapshot.data();
        const checkIn = checkInSnapshot.data();
        const restaurantId = requireStoredId(
          merchant.restaurantId,
          "merchant-restaurant-invalid",
          HttpsError
        );
        if (checkIn.restaurantId !== restaurantId) {
          throw new HttpsError(
            "permission-denied",
            "This merchant cannot approve this check-in."
          );
        }

        const restaurantRef = db.collection("restaurants").doc(restaurantId);
        const restaurantSnapshot = await transaction.get(restaurantRef);
        if (!restaurantSnapshot.exists) {
          throw new HttpsError("not-found", "Restaurant not found.");
        }
        const restaurant = restaurantSnapshot.data();
        if (
          typeof restaurant.ownerId === "string" &&
          restaurant.ownerId.length > 0 &&
          restaurant.ownerId !== uid
        ) {
          throw new HttpsError(
            "permission-denied",
            "This merchant does not own the restaurant."
          );
        }
        if (restaurant.active === false) {
          throw businessError(
            HttpsError,
            "restaurant-inactive",
            "Restaurant is inactive."
          );
        }

        const customerId = requireStoredId(
          checkIn.customerId,
          "check-in-customer-invalid",
          HttpsError
        );
        const expiresAt = timestampDate(
          checkIn.expiresAt,
          "check-in-expiration-invalid",
          HttpsError
        );

        if (operationSnapshot.exists) {
          return existingOperationResult(
            operationSnapshot.data(),
            { checkInId, operationId, uid, restaurantId },
            HttpsError
          );
        }

        if (checkIn.status === "approved") {
          if (
            checkIn.syncOperationId !== operationId ||
            typeof checkIn.visitId !== "string" ||
            checkIn.visitId.length === 0
          ) {
            throw new HttpsError(
              "already-exists",
              "Check-in was already processed by another operation.",
              { reason: "check-in-operation-conflict" }
            );
          }
          const existingVisitRef = db
            .collection("visits")
            .doc(checkIn.visitId);
          const existingVisitSnapshot = await transaction.get(existingVisitRef);
          if (
            !existingVisitSnapshot.exists ||
            existingVisitSnapshot.data().checkInId !== checkInId ||
            existingVisitSnapshot.data().operationId !== operationId
          ) {
            throw businessError(
              HttpsError,
              "approved-visit-inconsistent",
              "Approved check-in has no coherent visit."
            );
          }
          const legacyResult = resultPayload({
            checkInId,
            visitId: checkIn.visitId,
            operationId,
            alreadyProcessed: true,
            pointsAwarded: numberOrZero(checkIn.pointsAwarded),
            rewardId: null,
          });
          transaction.create(operationRef, {
            ...legacyResult,
            merchantUid: uid,
            restaurantId,
            completedAt: FieldValue.serverTimestamp(),
          });
          return legacyResult;
        }
        if (checkIn.status !== "pending") {
          throw businessError(
            HttpsError,
            `check-in-${String(checkIn.status || "invalid")}`,
            "Check-in is not pending."
          );
        }
        if (expiresAt.getTime() <= receivedAt.getTime()) {
          throw businessError(
            HttpsError,
            "check-in-expired",
            "Check-in expired before reaching the server."
          );
        }

        const policy = validationPolicy(restaurant.validationPolicy);
        const timeZone = validTimeZone(restaurant.timeZone)
          ? restaurant.timeZone
          : DEFAULT_TIME_ZONE;
        const visitId = deterministicVisitId({
          policy,
          restaurantId,
          customerId,
          checkInId,
          receivedAt,
          timeZone,
        });
        const visitRef = db.collection("visits").doc(visitId);
        const notificationRef = db
          .collection("notifications")
          .doc(`checkin-sync-${checkInId}`);
        const lockRef = db
          .collection("loyaltyTransactionLocks")
          .doc(`${restaurantId}_${customerId}`);
        const visitsQuery = db
          .collection("visits")
          .where("restaurantId", "==", restaurantId)
          .where("userId", "==", customerId)
          .orderBy("timestamp", "desc");
        const referralsQuery = db
          .collection("referrals")
          .where("referredUserId", "==", customerId);

        const [
          visitSnapshot,
          notificationSnapshot,
          lockSnapshot,
          visits,
          referrals,
        ] =
          await Promise.all([
            transaction.get(visitRef),
            transaction.get(notificationRef),
            transaction.get(lockRef),
            transaction.get(visitsQuery),
            transaction.get(referralsQuery),
          ]);
        void lockSnapshot;

        if (visitSnapshot.exists) {
          const visit = visitSnapshot.data();
          if (
            visit.checkInId === checkInId &&
            visit.operationId === operationId
          ) {
            throw businessError(
              HttpsError,
              "operation-state-incomplete",
              "Visit exists without a completed operation record."
            );
          }
          throw new HttpsError(
            "already-exists",
            "A visit already exists for this validation period.",
            { reason: "visit-already-exists" }
          );
        }

        const confirmedVisits = visits.docs.map((document) => document.data());
        enforceFrequency({
          policy,
          minimumHours: positiveInteger(
            restaurant.minimumHoursBetweenVisits,
            4
          ),
          confirmedVisits,
          receivedAt,
          timeZone,
          HttpsError,
        });

        const pointsAwarded = nonNegativeInteger(
          restaurant.pointsPerVisit,
          "restaurant-points-invalid",
          HttpsError
        );
        const existingCount = confirmedVisits.length;
        const previousCycle = rewardCycle({
          visitCount: existingCount,
          restaurant,
          HttpsError,
        });
        const nextCycle = rewardCycle({
          visitCount: existingCount + 1,
          restaurant,
          HttpsError,
        });
        const rewardId = nextCycle > previousCycle && nextCycle > 0
          ? `${restaurantId}_${customerId}_cycle_${nextCycle}`
          : null;
        const rewardRef = rewardId
          ? db.collection("rewards").doc(rewardId)
          : null;
        const rewardSnapshot = rewardRef
          ? await transaction.get(rewardRef)
          : null;
        const eligibleReferrals = existingCount === 0
          ? referrals.docs.filter((document) => {
            const referral = document.data();
            return referral.status === "pending" &&
              referral.referredUserId === customerId &&
              validId(referral.referrerId) &&
              referral.referrerId !== customerId &&
              (referral.restaurantId === undefined ||
                referral.restaurantId === null ||
                referral.restaurantId === restaurantId);
          })
          : [];
        const referralNotifications = await Promise.all(
          eligibleReferrals.map((document) =>
            transaction.get(
              db.collection("notifications").doc(
                `referral-reward-${document.id}`
              )
            )
          )
        );

        // All transaction reads are complete before this point.
        transaction.create(visitRef, {
          userId: customerId,
          restaurantId,
          timestamp: FieldValue.serverTimestamp(),
          checkInId,
          operationId,
        });
        transaction.update(checkInRef, {
          status: "approved",
          validatedAt: FieldValue.serverTimestamp(),
          validatedBy: uid,
          pointsAwarded,
          visitId,
          syncOperationId: operationId,
        });
        transaction.set(
          lockRef,
          {
            lastOperationId: operationId,
            lastVisitId: visitId,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        let createdRewardId = null;
        if (rewardRef && rewardSnapshot && !rewardSnapshot.exists) {
          const rewardLabel = stringOrDefault(
            restaurant.rewardLabel,
            "Récompense fidélité"
          );
          transaction.create(rewardRef, {
            userId: customerId,
            restaurantName: stringOrDefault(
              restaurant.name,
              "Commerce partenaire"
            ),
            restaurantId,
            label: rewardLabel,
            expiresAt: datePlusDays(receivedAt, 30),
            status: "available",
            cycle: nextCycle,
          });
          createdRewardId = rewardId;
        }

        if (!notificationSnapshot.exists) {
          const rewardUnlocked = createdRewardId !== null;
          transaction.create(notificationRef, {
            recipientType: "client",
            userId: customerId,
            restaurantId,
            title: rewardUnlocked
              ? "Récompense débloquée"
              : "Visite validée",
            body: rewardUnlocked
              ? `${stringOrDefault(
                  restaurant.rewardLabel,
                  "Une récompense"
                )} vous attend.`
              : `Votre visite a été confirmée. +${pointsAwarded} points.`,
            type: rewardUnlocked ? "reward_unlocked" : "visit_validated",
            relatedId: checkInId,
            createdAt: FieldValue.serverTimestamp(),
            read: false,
            isRead: false,
          });
        }

        const referralRewardIds = [];
        eligibleReferrals.forEach((document, index) => {
          const referral = document.data();
          transaction.update(document.ref, {
            restaurantId: referral.restaurantId || restaurantId,
            status: "rewarded",
            pointsEarned: REFERRAL_BONUS_POINTS,
            completedAt: FieldValue.serverTimestamp(),
            rewardedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          if (!referralNotifications[index].exists) {
            transaction.create(referralNotifications[index].ref, {
              recipientType: "client",
              userId: referral.referrerId,
              restaurantId,
              title: "Parrainage réussi",
              body: `${stringOrDefault(
                referral.name,
                "Votre filleul"
              )} a effectué sa première visite validée.`,
              type: "referral_rewarded",
              relatedId: document.id,
              createdAt: FieldValue.serverTimestamp(),
              read: false,
              isRead: false,
            });
          }
          referralRewardIds.push(document.id);
        });

        const result = resultPayload({
          checkInId,
          visitId,
          operationId,
          alreadyProcessed: false,
          pointsAwarded,
          rewardId: createdRewardId,
          referralRewardIds,
        });
        transaction.create(operationRef, {
          ...result,
          merchantUid: uid,
          restaurantId,
          completedAt: FieldValue.serverTimestamp(),
        });
        return result;
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (isUnavailable(error)) {
        throw new HttpsError("unavailable", "Backend temporarily unavailable.");
      }
      console.error("approveCheckInSecure failed", error);
      throw new HttpsError("internal", "Unable to approve check-in.");
    }
  };
}

function validateInput(data, HttpsError) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Invalid request payload.");
  }
  const keys = Object.keys(data);
  if (keys.some((key) => !ALLOWED_INPUT_KEYS.has(key))) {
    throw new HttpsError("invalid-argument", "Unexpected request field.");
  }
  const checkInId = validId(data.checkInId) ? data.checkInId : null;
  const operationId = typeof data.operationId === "string"
    ? data.operationId
    : null;
  if (
    !checkInId ||
    !operationId ||
    operationId !== `approveCheckIn:${checkInId}` ||
    operationId.length > MAX_ID_LENGTH + 15
  ) {
    throw new HttpsError("invalid-argument", "Invalid operation identifiers.");
  }
  return { checkInId, operationId };
}

function validId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_ID_LENGTH &&
    !value.includes("/") &&
    !value.includes("..")
  );
}

function requireStoredId(value, reason, HttpsError) {
  if (!validId(value)) {
    throw businessError(HttpsError, reason, "Stored identifier is invalid.");
  }
  return value;
}

function timestampDate(value, reason, HttpsError) {
  const date = value && typeof value.toDate === "function"
    ? value.toDate()
    : value instanceof Date
      ? value
      : null;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw businessError(HttpsError, reason, "Stored timestamp is invalid.");
  }
  return date;
}

function validationPolicy(value) {
  return value === "onceEveryXHours" || value === "perTransaction"
    ? value
    : "oncePerDay";
}

function enforceFrequency({
  policy,
  minimumHours,
  confirmedVisits,
  receivedAt,
  timeZone,
  HttpsError,
}) {
  if (policy === "perTransaction" || confirmedVisits.length === 0) return;
  const dates = confirmedVisits
    .map((visit) => timestampDate(visit.timestamp, "visit-time-invalid", HttpsError))
    .sort((a, b) => b.getTime() - a.getTime());
  const latest = dates[0];
  const blocked = policy === "onceEveryXHours"
    ? latest.getTime() + minimumHours * 60 * 60 * 1000 > receivedAt.getTime()
    : dayKey(latest, timeZone) === dayKey(receivedAt, timeZone);
  if (blocked) {
    throw businessError(
      HttpsError,
      "frequency-rule-conflict",
      "Visit frequency rule prevents this approval."
    );
  }
}

function rewardCycle({ visitCount, restaurant, HttpsError }) {
  if (restaurant.loyaltyProgramEnabled === false) return 0;
  const threshold = positiveInteger(
    restaurant.rewardThreshold,
    null
  );
  if (threshold === null) {
    throw businessError(
      HttpsError,
      "restaurant-reward-threshold-invalid",
      "Loyalty configuration is invalid."
    );
  }
  const type = restaurant.loyaltyProgramType === "points"
    ? "points"
    : "visits";
  const points = nonNegativeInteger(
    restaurant.pointsPerVisit,
    "restaurant-points-invalid",
    HttpsError
  );
  const value = type === "points" ? visitCount * points : visitCount;
  return Math.floor(value / threshold);
}

function deterministicVisitId({
  policy,
  restaurantId,
  customerId,
  checkInId,
  receivedAt,
  timeZone,
}) {
  if (policy === "oncePerDay") {
    const parts = dateParts(receivedAt, timeZone);
    return `${restaurantId}_${customerId}_${parts.year}-${parts.month}-${parts.day}`;
  }
  return `checkin_${checkInId}`;
}

function dayKey(date, timeZone) {
  const parts = dateParts(date, timeZone);
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function dateParts(date, timeZone) {
  const values = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);
  const part = (type) => Number(values.find((item) => item.type === type).value);
  return { year: part("year"), month: part("month"), day: part("day") };
}

function validTimeZone(value) {
  if (typeof value !== "string" || value.length > 64) return false;
  try {
    new Intl.DateTimeFormat("en", { timeZone: value }).format();
    return true;
  } catch (_) {
    return false;
  }
}

function existingOperationResult(operation, expected, HttpsError) {
  if (
    operation.success !== true ||
    operation.status !== "approved" ||
    operation.checkInId !== expected.checkInId ||
    operation.operationId !== expected.operationId ||
    operation.merchantUid !== expected.uid ||
    operation.restaurantId !== expected.restaurantId ||
    !validId(operation.visitId)
  ) {
    throw new HttpsError(
      "already-exists",
      "Operation identifier is already used.",
      { reason: "operation-id-conflict" }
    );
  }
  return resultPayload({
    checkInId: operation.checkInId,
    visitId: operation.visitId,
    operationId: operation.operationId,
    alreadyProcessed: true,
    pointsAwarded: numberOrZero(operation.pointsAwarded),
    rewardId: typeof operation.rewardId === "string"
      ? operation.rewardId
      : null,
    referralRewardIds: Array.isArray(operation.referralRewardIds)
      ? operation.referralRewardIds.filter(validId)
      : [],
  });
}

function resultPayload({
  checkInId,
  visitId,
  operationId,
  alreadyProcessed,
  pointsAwarded,
  rewardId,
  referralRewardIds = [],
}) {
  return {
    success: true,
    checkInId,
    visitId,
    operationId,
    status: "approved",
    alreadyProcessed,
    pointsAwarded,
    rewardId,
    referralRewardIds,
  };
}

function businessError(HttpsError, reason, message) {
  return new HttpsError("failed-precondition", message, { reason });
}

function positiveInteger(value, fallback) {
  return Number.isInteger(value) && value > 0 ? value : fallback;
}

function nonNegativeInteger(value, reason, HttpsError) {
  if (!Number.isInteger(value) || value < 0) {
    throw businessError(HttpsError, reason, "Stored number is invalid.");
  }
  return value;
}

function numberOrZero(value) {
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

function stringOrDefault(value, fallback) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

function datePlusDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function isUnavailable(error) {
  return Boolean(
    error &&
      (error.code === 14 ||
        error.code === "unavailable" ||
        error.code === "deadline-exceeded")
  );
}

module.exports = {
  createApproveCheckInSecure,
  deterministicVisitId,
  rewardCycle,
};
