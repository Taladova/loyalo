const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  createApproveCheckInSecure,
} = require("./src/approve_check_in_secure");
const { createRejectCheckInSecure } = require("./src/reject_check_in_secure");

initializeApp();
setGlobalOptions({ region: "us-central1" });

const db = getFirestore();

exports.approveCheckInSecure = onCall(
  createApproveCheckInSecure({ db, FieldValue, HttpsError })
);

exports.rejectCheckInSecure = onCall(
  createRejectCheckInSecure({ db, FieldValue, HttpsError })
);

exports.sendPushForNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const notification = event.data && event.data.data();
    if (!notification || !notification.userId) return;

    const devices = await db
      .collection("users")
      .doc(notification.userId)
      .collection("devices")
      .where("active", "==", true)
      .get();

    const tokens = devices.docs
      .map((doc) => ({ id: doc.id, ref: doc.ref, token: doc.data().token }))
      .filter((device) => typeof device.token === "string" && device.token);

    if (tokens.length === 0) return;

    const messageBase = {
      notification: {
        title: notification.title || "Loyalo",
        body: notification.body || "",
      },
      data: {
        type: notification.type || "unknown",
        notificationId: event.params.notificationId,
        restaurantId: notification.restaurantId || "",
        relatedId: notification.relatedId || "",
      },
      android: {
        notification: {
          channelId: "loyalo",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const results = await Promise.allSettled(
      tokens.map((device) =>
        getMessaging().send({ ...messageBase, token: device.token })
      )
    );

    await Promise.all(
      results.map((result, index) => {
        if (result.status === "fulfilled") return null;
        const code = result.reason && result.reason.code;
        if (
          code !== "messaging/registration-token-not-registered" &&
          code !== "messaging/invalid-registration-token"
        ) {
          return null;
        }
        return tokens[index].ref.set(
          {
            active: false,
            invalidatedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      })
    );
  }
);
