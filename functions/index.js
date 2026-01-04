const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");
const { defineSecret } = require("firebase-functions/params");
const SENDGRID_KEY = defineSecret("SENDGRID_KEY");

initializeApp();

/* =========================================================
   DAILY RESTAURANT REMINDER
   ⏰ Runs every 15 minutes
   🔔 Sends reminder 1 hour before closing time
========================================================= */
exports.sendDailyDonationReminder = onSchedule(
  {
    schedule: "*/15 * * * *", // every 15 minute
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const db = getFirestore();
    const now = new Date();
    // Convert to Kuala Lumpur time (UTC+8) to match user-local dates/times
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    const nowKL = new Date(utc + 8 * 60 * 1000);
    const today = nowKL.toISOString().split("T")[0]; // YYYY-MM-DD in KL timezone


    const usersSnap = await db
      .collection("users")
      .where("role", "==", "restaurant")
      .where("approved", "==", true)
      .get();

    const messages = [];
    const updates = [];

    usersSnap.forEach((doc) => {
      const user = doc.data();
      console.log(`Checking user ${doc.id}: openingTime=${user.openingTime}, closingTime=${user.closingTime}, fcmToken=${!!user.fcmToken}, lastReminderDate=${user.lastReminderDate}`);

      if (!user.fcmToken) {
        console.log(`Skipping ${doc.id}: no fcmToken`);
        return;
      }
      if (!user.closingTime) {
        console.log(`Skipping ${doc.id}: no closingTime`);
        return;
      }

      // closingTime expected format: "HH:mm" (24h)
      const closingStr = String(user.closingTime);
      const parts = closingStr.split(":").map(Number);
      if (parts.length < 2 || parts.some((n) => Number.isNaN(n))) {
        console.log(`Skipping ${doc.id}: invalid closingTime format (${user.closingTime})`);
        return;
      }

      const [closeHour, closeMinute] = parts;

      // Parse openingTime if available to detect overnight closing (e.g., open 10:00 -> close 02:00)
      let openingMins = null;
      if (user.openingTime) {
        try {
          const opParts = String(user.openingTime).split(":").map(Number);
          if (opParts.length >= 2 && !opParts.some((n) => Number.isNaN(n))) {
            openingMins = opParts[0] * 60 + opParts[1];
          }
        } catch (e) {
          // ignore parse
        }
      }

      // Use Kuala Lumpur 'now' for comparisons
      const closingDateTime = new Date(nowKL);
      closingDateTime.setHours(closeHour, closeMinute, 0, 0);

      // Determine if this is an overnight closing (e.g., open 10:41 AM, close 3:30 AM next day)
      if (openingMins != null) {
        const closeMins = closeHour * 60 + closeMinute;
        const nowMins = nowKL.getHours() * 60 + nowKL.getMinutes();
        
        // If closing < opening, it's an overnight schedule
        if (closeMins <= openingMins) {
          // Are we currently in the "open" period (after opening) or "closing soon" period (before closing)?
          if (nowMins >= openingMins) {
            // We're after opening time, so closing is tonight/early tomorrow morning
            closingDateTime.setDate(closingDateTime.getDate() + 1);
            console.log(`Overnight schedule - closing is tomorrow early morning for ${doc.id}`);
          } else if (nowMins <= closeMins) {
            // We're in early morning before closing time - closing is TODAY
            console.log(`Overnight schedule - currently before closing time for ${doc.id}`);
          } else {
            // We're between closing and opening - closed right now, next closing is tomorrow
            closingDateTime.setDate(closingDateTime.getDate() + 1);
            console.log(`Overnight schedule - currently closed, next closing is tomorrow for ${doc.id}`);
          }
        } else if (closingDateTime <= nowKL) {
          // Normal schedule, but closing time already passed today
          closingDateTime.setDate(closingDateTime.getDate() + 1);
          console.log(`Adjusted closingDateTime to next day for ${doc.id} because closingTime <= now`);
        }
      } else {
        // no opening time; if closing appears earlier than now and is early morning, treat as next day
        if (closingDateTime <= nowKL && closeHour < 12) {
          closingDateTime.setDate(closingDateTime.getDate() + 1);
          console.log(`Adjusted closingDateTime to next day for ${doc.id} (no openingTime, early close)`);
        }
      }

      // Reminder = 1 hour before closing
      const reminderTime = new Date(closingDateTime.getTime() - 60 * 60 * 1000);

      // Check if reminder time has arrived
      if (reminderTime <= nowKL) {
        const minutesSinceReminder = (nowKL - reminderTime) / (1000 * 60);
        
        // Only send if within 2-minute window AND haven't sent today yet
        if (minutesSinceReminder <= 2) {
          
          // Check if we've already sent a reminder today
          if (user.lastReminderDate === today) {
            console.log(`Skipping ${doc.id}: already reminded today (${today})`);
            return;
          }

          console.log(`Sending reminder to ${doc.id}; reminderTime=${reminderTime.toISOString()}, nowKL=${nowKL.toISOString()}`);
          messages.push({
            token: user.fcmToken,
            notification: {
              title: "Leftover food reminder 🍱",
              body: "You're closing in 1 hour. Any surplus food to donate?",
            },
            data: {
              action: "DONATE_ACTION",
            },
          });

          // Store today's date to prevent duplicate reminders
          updates.push(
            db.collection("users").doc(doc.id).update({
              lastReminderDate: today,
            })
          );
        } else {
          console.log(`Reminder window passed for ${doc.id}; reminderTime was ${reminderTime.toISOString()}, nowKL=${nowKL.toISOString()}, minutesSince=${minutesSinceReminder.toFixed(1)}`);
        }
      } else {
        const minutesUntilReminder = (reminderTime - nowKL) / (1000 * 60);
        console.log(`Not time yet for ${doc.id}; reminder=${reminderTime.toISOString()}, nowKL=${nowKL.toISOString()}, minutesUntil=${minutesUntilReminder.toFixed(1)}`);
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

/* =========================================================
   📧 EMAIL USER WHEN ACCOUNT IS APPROVED
========================================================= */
exports.notifyUserApproved = onDocumentUpdated(
  {
    document: "users/{userId}",
    secrets: [SENDGRID_KEY],
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.approved === true || after.approved !== true) return;

    const sgMail = require("@sendgrid/mail");
    sgMail.setApiKey(SENDGRID_KEY.value());

    await sgMail.send({
      to: after.email,
      from: "no-reply@food4need.app",
      subject: "Your account has been approved ✅",
      text: "Your Food4Need account is now approved. You may log in.",
    });
  }
);
