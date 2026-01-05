import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/fcm_service.dart';

// pages
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/restaurant_dashboard.dart';
import 'pages/restaurant_profile.dart';
import 'pages/ngo_dashboard.dart';
import 'pages/ngo_profile.dart';
import 'pages/onboarding_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/admin_activity.dart';
import 'pages/profile_page.dart';
import 'pages/donation_page.dart';
import 'pages/mydonation_page.dart';
import 'pages/ngo_donation_details.dart';
import 'pages/ngo_accepted_page.dart';
import 'pages/ngo_history_page.dart';
import 'pages/restaurant_history_page.dart';
import 'pages/edit_donation_page.dart';
import 'pages/chat_list_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? pendingAction;
String? cachedRole;

// ================= BACKGROUND HANDLER =================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 Background message: ${message.data}");
}

// ================= ROLE FETCH (CACHED) =================
Future<String?> _getUserRole() async {
  if (cachedRole != null) return cachedRole;

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final snap = await FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .get();

  cachedRole = snap.data()?["role"];
  return cachedRole;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (FirebaseAuth.instance.currentUser != null) {
    await FCMService.initFCM();
  }

  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    pendingAction = initialMsg.data["action"];
  }

  FirebaseMessaging.onMessage.listen((message) async {
    final action = message.data["action"];
    final role = await _getUserRole();
    if (role == null) return;

    if (action == "OPEN_NGO_DASHBOARD" && role != "ngo") return;
    if (action == "DONATE_ACTION" && role != "restaurant") return;

    if (navigatorKey.currentContext == null) return;

    showDialog(
      context: navigatorKey.currentContext!,
      builder: (_) => AlertDialog(
        title: Text(message.notification?.title ?? "Notification"),
        content: Text(message.notification?.body ?? ""),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(navigatorKey.currentContext!),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    final action = message.data["action"];
    final role = await _getUserRole();

    if (action == "OPEN_NGO_DASHBOARD" && role == "ngo") {
      navigatorKey.currentState?.pushNamed("/ngo-dashboard");
    }

    if (action == "DONATE_ACTION" && role == "restaurant") {
      navigatorKey.currentState?.pushNamed("/create-donation");
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool("onboarding_done") ?? false;

  runApp(MyApp(onboardingDone: onboardingDone));
}

// ================= APP =================
class MyApp extends StatelessWidget {
  final bool onboardingDone;
  const MyApp({super.key, required this.onboardingDone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: onboardingDone ? "/login" : "/onboarding",

      routes: {
        "/onboarding": (_) => const OnboardingPage(),
        "/login": (_) => const LoginPage(),
        "/register": (_) => const RegisterPage(),

        "/restaurant-dashboard": (_) => const RestaurantDashboard(),
        "/restaurant-profile-view": (_) =>
            const ProfilePage(role: "restaurant"),
        "/restaurant-profile-edit": (_) => const RestaurantProfile(),
        "/create-donation": (_) => const CreateDonationPage(),
        "/restaurant-donations": (_) => const RestaurantDonationsPage(),
        "/restaurant-history": (_) => const RestaurantHistoryPage(),
        "/edit-donation": (_) => const EditDonationPage(),

        "/ngo-dashboard": (_) => const NGODashboard(),
        "/ngo-profile-view": (_) => const ProfilePage(role: "ngo"),
        "/ngo-profile-edit": (_) => const NGOProfile(),
        "/ngo-accepted": (_) => const NGOAcceptedPage(),
        "/ngo-history": (_) => const NGOHistoryPage(),

        "/admin-dashboard": (_) => const AdminDashboard(),
        "/admin-activity": (_) => const AdminActivityPage(),

        "/chats": (_) => const ChatListPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == "/ngo-donation-details") {
          final donationId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => NGODonationDetails(donationId: donationId),
          );
        }
        return null;
      },

      builder: (context, child) {
        Future.microtask(() async {
          if (pendingAction != null) {
            final role = await _getUserRole();

            if (pendingAction == "DONATE_ACTION" && role == "restaurant") {
              navigatorKey.currentState?.pushNamed("/create-donation");
            }

            if (pendingAction == "OPEN_NGO_DASHBOARD" && role == "ngo") {
              navigatorKey.currentState?.pushNamed("/ngo-dashboard");
            }

            pendingAction = null;
          }
        });

        return child!;
      },
    );
  }
}
