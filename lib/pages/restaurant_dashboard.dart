import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  String restaurantName = "Restaurant Owner";
  int _currentIndex = 0;

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefae0),

      // ✅ APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Food4Need", style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "logout") {
                logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),

      // ✅ BODY
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $restaurantName 👋",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xffd4a373),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Manage your food donations",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // ACTION LIST
            Expanded(
              child: ListView(
                children: [
                  actionTile(
                    icon: Icons.volunteer_activism,
                    title: "My Donations",
                    subtitle: "View and manage your donations",
                    onTap: () {
                      Navigator.pushNamed(context, "/restaurant-donations");
                    },
                  ),
                  actionTile(
                    icon: Icons.add_circle_outline,
                    title: "Create Donation",
                    subtitle: "Donate surplus food",
                    onTap: () {
                      Navigator.pushNamed(context, "/create-donation");
                    },
                  ),
                  actionTile(
                    icon: Icons.person,
                    title: "My Profile",
                    subtitle: "View your restaurant profile",
                    onTap: () {
                      Navigator.pushNamed(context, "/restaurant-profile-view");
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ✅ FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xffd4a373),
        onPressed: () {
          Navigator.pushNamed(context, "/create-donation");
        },
        icon: const Icon(Icons.add),
        label: const Text("Donate Food"),
      ),

      // ✅ BOTTOM NAVIGATION (FIXED)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xffd4a373),
        onTap: (index) async {
          setState(() => _currentIndex = index);

          if (index == 1) {
            await Navigator.pushNamed(context, "/restaurant-donations");
            setState(() => _currentIndex = 0); // 👈 reset to Home
          } else if (index == 2) {
            await Navigator.pushNamed(context, "/restaurant-profile-view");
            setState(() => _currentIndex = 0); // 👈 reset to Home
          }
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "Donations",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // ✅ MATERIAL ACTION TILE
  Widget actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xfffaedcd),
          child: Icon(icon, color: const Color(0xffd4a373)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
