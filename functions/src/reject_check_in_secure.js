"use strict";

const MAX_ID_LENGTH = 128;
const ALLOWED_INPUT_KEYS = new Set(["checkInId", "operationId"]);

function createRejectCheckInSecure({ db, FieldValue, HttpsError }) {
  if (!db || !FieldValue || !HttpsError) {
    throw new TypeError("Missing rejectCheckInSecure dependency");
  }

  return async function rejectCheckInSecure(request) {
    const uid = request && request.auth && request.auth.uid;
    if (typeof uid !== "string" || uid.length === 0) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    const { checkInId, operationId } = validateInput(
      request && request.data,
      HttpsError
    );

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
            "This merchant cannot reject this check-in."
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

        if (operationSnapshot.exists) {
          return existingOperationResult(
            operationSnapshot.data(),
            { checkInId, operationId, uid, restaurantId },
            HttpsError
          );
        }

        if (checkIn.status === "rejected") {
          if (
            checkIn.syncOperationId !== operationId ||
            checkIn.rejectedBy !== uid
          ) {
            throw conflict(
              HttpsError,
              "check-in-operation-conflict",
              "Check-in was already processed by another operation."
            );
          }
          const result = resultPayload({
            checkInId,
            operationId,
            alreadyProcessed: true,
          });
          transaction.create(operationRef, {
            ...result,
            merchantUid: uid,
            restaurantId,
            completedAt: FieldValue.serverTimestamp(),
          });
          return result;
        }
        if (checkIn.status !== "pending") {
          throw conflict(
            HttpsError,
            `check-in-${String(checkIn.status || "invalid")}`,
            "Check-in cannot be rejected."
          );
        }

        const result = resultPayload({
          checkInId,
          operationId,
          alreadyProcessed: false,
        });
        transaction.update(checkInRef, {
          status: "rejected",
          rejectedAt: FieldValue.serverTimestamp(),
          rejectedBy: uid,
          syncOperationId: operationId,
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
      console.error("rejectCheckInSecure failed", error);
      throw new HttpsError("internal", "Unable to reject check-in.");
    }
  };
}

function validateInput(data, HttpsError) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Invalid request payload.");
  }
  if (Object.keys(data).some((key) => !ALLOWED_INPUT_KEYS.has(key))) {
    throw new HttpsError("invalid-argument", "Unexpected request field.");
  }
  const checkInId = validId(data.checkInId) ? data.checkInId : null;
  const operationId = typeof data.operationId === "string"
    ? data.operationId
    : null;
  if (
    !checkInId ||
    !operationId ||
    operationId !== `rejectCheckIn:${checkInId}` ||
    operationId.length > MAX_ID_LENGTH + 14
  ) {
    throw new HttpsError("invalid-argument", "Invalid operation identifiers.");
  }
  return { checkInId, operationId };
}

function existingOperationResult(operation, expected, HttpsError) {
  if (
    operation.success !== true ||
    operation.status !== "rejected" ||
    operation.checkInId !== expected.checkInId ||
    operation.operationId !== expected.operationId ||
    operation.merchantUid !== expected.uid ||
    operation.restaurantId !== expected.restaurantId
  ) {
    throw new HttpsError(
      "already-exists",
      "Operation identifier is already used.",
      { reason: "operation-id-conflict" }
    );
  }
  return resultPayload({
    checkInId: operation.checkInId,
    operationId: operation.operationId,
    alreadyProcessed: true,
  });
}

function resultPayload({ checkInId, operationId, alreadyProcessed }) {
  return {
    success: true,
    checkInId,
    operationId,
    status: "rejected",
    alreadyProcessed,
  };
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
    throw conflict(HttpsError, reason, "Stored identifier is invalid.");
  }
  return value;
}

function conflict(HttpsError, reason, message) {
  return new HttpsError("failed-precondition", message, { reason });
}

function isUnavailable(error) {
  return Boolean(
    error &&
      (error.code === 14 ||
        error.code === "unavailable" ||
        error.code === "deadline-exceeded")
  );
}

module.exports = { createRejectCheckInSecure };
