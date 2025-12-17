import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// import pages
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/restaurant_dashboard.dart';
import 'pages/restaurant_profile.dart';
import 'pages/ngo_dashboard.dart';
import 'pages/ngo_profile.dart';
import 'pages/onboarding_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔑 CHECK ONBOARDING STATE
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool("onboarding_done") ?? false;

  runApp(MyApp(onboardingDone: onboardingDone));
}

class MyApp extends StatelessWidget {
  final bool onboardingDone;

  const MyApp({super.key, required this.onboardingDone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ DECIDE FIRST SCREEN HERE
      initialRoute: onboardingDone ? "/login" : "/onboarding",

      routes: {
        "/onboarding": (context) => const OnboardingPage(),
        "/login": (context) => const LoginPage(),
        "/register": (context) => const RegisterPage(),
        "/restaurant-dashboard": (context) => const RestaurantDashboard(),
        "/restaurant-profile": (context) => const RestaurantProfile(),
        "/restaurant-profile-view": (context) =>
            const ProfilePage(role: "restaurant"),
        "/ngo-dashboard": (context) => const NGODashboard(),
        "/ngo-profile": (context) => const NGOProfile(),
        "/admin-dashboard": (context) => const AdminDashboard(),
        "/restaurant-profile-edit": (context) => const RestaurantProfile(),
        "/ngo-profile-edit": (context) => const NGOProfile(),
      },
    );
  }
}
