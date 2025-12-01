import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  String restaurantName =
      "Restaurant Owner"; // You can later fetch from Firestore

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      body: Column(
        children: [
          // ---------------- NAVBAR ----------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xffd4a373),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo / Title
                const Text(
                  "Food4Need - Restaurant Dashboard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Profile dropdown
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                  onSelected: (value) {
                    if (value == "profile") {
                      Navigator.pushNamed(context, "/restaurant-profile");
                    }
                    if (value == "logout") {
                      logout();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "profile",
                      child: Text("Edit Profile"),
                    ),
                    const PopupMenuItem(value: "logout", child: Text("Logout")),
                  ],
                ),
              ],
            ),
          ),

          // ---------------- HEADER ----------------
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, $restaurantName 👋",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffd4a373),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Manage your donations and profile here.",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),

          // ---------------- ACTION CARDS ----------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  dashboardCard(
                    icon: Icons.person,
                    title: "Edit Profile",
                    onTap: () =>
                        Navigator.pushNamed(context, "/restaurant-profile"),
                  ),
                  dashboardCard(
                    icon: Icons.volunteer_activism,
                    title: "Create Donation",
                    onTap: () =>
                        Navigator.pushNamed(context, "/create-donation"),
                  ),
                  dashboardCard(
                    icon: Icons.list_alt,
                    title: "My Donations",
                    onTap: () =>
                        Navigator.pushNamed(context, "/restaurant-donations"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------- CARD WIDGET -------------
  Widget dashboardCard({
    required IconData icon,
    required String title,
    required Function onTap,
  }) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: Color(0xffd4a373)),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
