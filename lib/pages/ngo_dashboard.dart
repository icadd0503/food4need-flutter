import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  String _ngoName = "NGO Partner";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNGOProfile();
  }

  // Helper method to fetch the NGO's name for a personalized greeting
  Future<void> _loadNGOProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (snap.exists) {
        final data = snap.data()!;
        if (mounted) {
          setState(() {
            // Assumes the name field stores the NGO's name
            _ngoName = data["name"] ?? "NGO Partner";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Show an error if data fetching fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Improved logout function using async/await
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // Use pushNamedAndRemoveUntil to clear the navigation stack after logout
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),

      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text(
          "NGO Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Ensures back button is white
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) {
              if (value == "profile") {
                Navigator.pushNamed(context, "/ngo-profile");
              } else if (value == "logout") {
                _logout();
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

      body: SingleChildScrollView(
        // Changed to SingleChildScrollView for safety
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome $_ngoName 👋", // Personalized Greeting
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xffd4a373),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Here are your available actions:",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            // Dashboard buttons section
            _dashboardButton(
              context,
              title: "View Nearby Donations",
              icon: Icons.location_on,
              onTap: () {
                // Assuming route for this page is /ngo-donations-map
                Navigator.pushNamed(context, "/ngo-donations-map");
              },
            ),

            _dashboardButton(
              context,
              title: "Accepted Donations",
              icon: Icons.check_circle,
              onTap: () {
                // Assuming route for this page is /ngo-accepted
                Navigator.pushNamed(context, "/ngo-accepted");
              },
            ),

            _dashboardButton(
              context,
              title: "Reserved Donations",
              icon: Icons.bookmark,
              onTap: () {
                // Assuming route for this page is /ngo-reserved
                Navigator.pushNamed(context, "/ngo-reserved");
              },
            ),
          ],
        ),
      ),
    );
  }

  // Extracted widget method with cleaner styling
  Widget _dashboardButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 30, color: const Color(0xffd4a373)),
              const SizedBox(width: 20),
              Expanded(
                // Use Expanded to prevent layout overflow
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
