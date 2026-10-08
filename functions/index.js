const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();

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
      .map((doc) => ({ id: doc.id, token: doc.data().token }))
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
        return devices.docs[index].ref.set(
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
