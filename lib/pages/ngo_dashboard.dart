import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/profile_page.dart';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  String _ngoName = "NGO Partner";
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNGOProfile();
  }

  Future<void> _loadNGOProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (snap.exists) {
      setState(() {
        _ngoName = snap.data()?["name"] ?? "NGO Partner";
      });
    }

    setState(() => _isLoading = false);
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
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
        title: const Text("Food4Need", style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "logout") _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hi, $_ngoName 👋",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xffd4a373),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Find and manage food donations",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: [
                  _actionTile(
                    icon: Icons.location_on,
                    title: "Nearby Donations",
                    subtitle: "View donations near you",
                    onTap: () async {
                      await Navigator.pushNamed(context, "/ngo-donations-map");
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _actionTile(
                    icon: Icons.check_circle,
                    title: "Accepted Donations",
                    subtitle: "Donations you accepted",
                    onTap: () async {
                      await Navigator.pushNamed(context, "/ngo-accepted");
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _actionTile(
                    icon: Icons.person,
                    title: "My Profile",
                    subtitle: "View NGO profile",
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfilePage(role: "ngo"),
                        ),
                      );
                      setState(() => _currentIndex = 0);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xffd4a373),
        onTap: (index) async {
          setState(() => _currentIndex = index);

          if (index == 1) {
            await Navigator.pushNamed(context, "/ngo-accepted");
            setState(() => _currentIndex = 0);
          } else if (index == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage(role: "ngo")),
            );
            setState(() => _currentIndex = 0);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: "Accepted",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _actionTile({
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
