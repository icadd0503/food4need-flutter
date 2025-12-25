import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /* =========================================================
     INIT FCM (CALL AFTER LOGIN SUCCESS)
  ========================================================= */
  static Future<void> initFCM() async {
    // 1️⃣ Request permission (Android 13 / iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 2️⃣ Get user role
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return;

    final role = userDoc.data()?["role"];

    // 3️⃣ Get FCM token
    final token = await _messaging.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).update(
        {
          "fcmToken": token,
          "fcmRole": role, // 🔥 IMPORTANT
          "updatedAt": FieldValue.serverTimestamp(),
        },
      );
    }

    // 4️⃣ Listen token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection("users").doc(uid).update({
          "fcmToken": newToken,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    });

    // 5️⃣ Handle foreground messages SAFELY
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _handleIncomingMessage(message);
    });
  }

  /* =========================================================
     HANDLE NOTIFICATION (ROLE FILTERING)
  ========================================================= */
  static Future<void> _handleIncomingMessage(RemoteMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (!userDoc.exists) return;

    final role = userDoc.data()?["role"];

    // 🔥 IMPORTANT: ONLY NGOs SEE NGO NOTIFICATIONS
    if (role != "ngo") return;

    // OPTIONAL: filter by action
    final action = message.data["action"];

    if (action != "OPEN_NGO_DASHBOARD") return;

    // At this point:
    // ✔ user is NGO
    // ✔ notification is relevant

    debugPrint("🔔 NGO Notification received: ${message.notification?.title}");
  }

  /* =========================================================
     CLEAR TOKEN ON LOGOUT (VERY IMPORTANT)
  ========================================================= */
  static Future<void> clearFCMToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "fcmToken": FieldValue.delete(),
      "fcmRole": FieldValue.delete(),
    });
  }
}
