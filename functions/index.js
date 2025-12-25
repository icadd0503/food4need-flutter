const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

/* =========================================================
   DAILY RESTAURANT REMINDER
   ⏰ Runs every 15 minutes
   🔔 Sends reminder 1 hour before closing time
========================================================= */
exports.sendDailyDonationReminder = onSchedule(
  {
    schedule: "*/15 * * * *", // every 15 minutes
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const today = now.toISOString().split("T")[0]; // YYYY-MM-DD

    const usersSnap = await db
      .collection("users")
      .where("role", "==", "restaurant")
      .where("approved", "==", true)
      .get();

    const messages = [];
    const updates = [];

    usersSnap.forEach((doc) => {
      const user = doc.data();

      if (!user.fcmToken || !user.closingTime) return;
      if (user.lastReminderDate === today) return;

      // closingTime format: "19:00"
      const [closeHour, closeMinute] = user.closingTime
        .split(":")
        .map(Number);

      const closingDateTime = new Date(now);
      closingDateTime.setHours(closeHour, closeMinute, 0, 0);

      // Reminder = 1 hour before closing
      const reminderTime = new Date(closingDateTime);
      reminderTime.setHours(reminderTime.getHours() - 1);

      const diffMinutes = Math.abs(now - reminderTime) / (1000 * 60);

      // allow 15 min window
      if (diffMinutes <= 15) {
        messages.push({
          token: user.fcmToken,
          notification: {
            title: "Leftover food reminder 🍱",
            body: "You’re closing in 1 hour. Any surplus food to donate?",
          },
          data: {
            action: "DONATE_ACTION",
          },
        });

        updates.push(
          db.collection("users").doc(doc.id).update({
            lastReminderDate: today,
          })
        );
      }
    });

    if (messages.length > 0) {
      await getMessaging().sendEach(messages);
      await Promise.all(updates);
    }

    return null;
  }
);

/* =========================================================
   🔔 NOTIFY NEARBY NGOs WHEN DONATION IS CREATED
========================================================= */
exports.notifyNearbyNGOs = onDocumentCreated(
  "donations/{donationId}",
  async (event) => {
    const donation = event.data.data();
    if (!donation) return;

    const { latitude, longitude, title } = donation;
    if (latitude == null || longitude == null) return;

    const db = getFirestore();

    const ngosSnap = await db
      .collection("users")
      .where("role", "==", "ngo")
      .where("approved", "==", true)
      .get();

    const messages = [];

    ngosSnap.forEach((doc) => {
      const ngo = doc.data();
      if (!ngo.fcmToken || ngo.latitude == null || ngo.longitude == null)
        return;

      const distance = calculateDistanceKm(
        latitude,
        longitude,
        ngo.latitude,
        ngo.longitude
      );

      if (distance <= 10) {
        messages.push({
          token: ngo.fcmToken,
          notification: {
            title: "New Food Donation Nearby 🍱",
            body: title || "A restaurant just donated food",
          },
          data: {
            action: "OPEN_NGO_DASHBOARD",
          },
        });
      }
    });

    if (messages.length > 0) {
      await getMessaging().sendEach(messages);
    }

    return null;
  }
);

/* =========================================================
   NGO reserves → notify Restaurant
========================================================= */
exports.notifyRestaurantOnReserve = onDocumentUpdated(
  "donations/{donationId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== "available" || after.status !== "reserved") return;

    const db = getFirestore();
    const restaurantSnap = await db
      .collection("users")
      .doc(after.restaurantId)
      .get();

    if (!restaurantSnap.exists) return;

    const token = restaurantSnap.data().fcmToken;
    if (!token) return;

    await getMessaging().send({
      token,
      notification: {
        title: "Donation Reserved 🧾",
        body: `NGO reserved "${after.title}". Please confirm.`,
      },
      data: {
        action: "OPEN_RESTAURANT_DASHBOARD",
      },
    });
  }
);

/* =========================================================
   Restaurant confirms → notify NGO
========================================================= */
exports.notifyNGOOnConfirm = onDocumentUpdated(
  "donations/{donationId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== "reserved" || after.status !== "confirmed") return;

    const db = getFirestore();
    const ngoSnap = await db.collection("users").doc(after.ngoId).get();

    if (!ngoSnap.exists) return;

    const token = ngoSnap.data().fcmToken;
    if (!token) return;

    await getMessaging().send({
      token,
      notification: {
        title: "Pickup Confirmed ✅",
        body: `Restaurant confirmed "${after.title}".`,
      },
      data: {
        action: "OPEN_NGO_DASHBOARD",
      },
    });
  }
);

/* =========================================================
   NGO collects → notify Restaurant
========================================================= */
exports.notifyRestaurantOnCollected = onDocumentUpdated(
  "donations/{donationId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== "confirmed" || after.status !== "completed") return;

    const db = getFirestore();
    const restaurantSnap = await db
      .collection("users")
      .doc(after.restaurantId)
      .get();

    if (!restaurantSnap.exists) return;

    const token = restaurantSnap.data().fcmToken;
    if (!token) return;

    await getMessaging().send({
      token,
      notification: {
        title: "Food Collected 🎉",
        body: `"${after.title}" has been collected. Thank you!`,
      },
      data: {
        action: "OPEN_RESTAURANT_HISTORY",
      },
    });
  }
);

/* =========================================================
   DISTANCE HELPER (HAVERSINE)
========================================================= */
function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) *
      Math.cos(deg2rad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function deg2rad(deg) {
  return deg * (Math.PI / 180);
}
