import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// import pages
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/restaurant_dashboard.dart';
import 'pages/restaurant_profile.dart';
import 'pages/ngo_dashboard.dart';
import 'pages/ngo_profile.dart';
import 'pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: "/onboarding",

      routes: {
        "/onboarding": (context) => OnboardingPage(),
        "/login": (context) => const LoginPage(),
        "/register": (context) => const RegisterPage(),
        "/restaurant-dashboard": (context) => RestaurantDashboard(),
        "/restaurant-profile": (context) => RestaurantProfile(),
        "/ngo-dashboard": (context) => NGODashboard(),
        "/ngo-profile": (context) => NGOProfile(),
      },
    );
  }
}
