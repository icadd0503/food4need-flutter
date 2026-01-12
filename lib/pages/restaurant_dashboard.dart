import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../pages/mydonation_page.dart';
import '../pages/restaurant_history_page.dart';
import '../pages/profile_page.dart';
import '../services/fcm_service.dart';
import '../pages/chat_list_page.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _index = 0;
  String restaurantName = "Restaurant";
  bool loadingStats = true;

  int activeCount = 0;
  int reservedCount = 0;
  int completedCount = 0;

  @override
  void initState() {
    super.initState();
    FCMService.initFCM();
    _loadUser();
    _loadStats();
    FirebaseMessaging.onMessage.listen((message) {});
  }

  // ================= PULL TO REFRESH =================
  Future<void> _onRefresh() async {
    await _loadUser();
    await _loadStats();
    setState(() {});
  }

  // ================= USER =================
  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (snap.exists) {
      setState(() {
        restaurantName = snap.data()?["name"] ?? "Restaurant";
      });
    }
  }

  // ================= STATS =================
  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final donations = await FirebaseFirestore.instance
        .collection("donations")
        .where("restaurantId", isEqualTo: uid)
        .get();

    int active = 0;
    int reserved = 0;
    int completed = 0;

    for (var d in donations.docs) {
      final data = d.data();
      final status = data["status"];
      final expiry = data["expiryAt"];

      final isExpired =
          expiry != null &&
          (expiry as Timestamp).toDate().isBefore(DateTime.now());

      if (status == "available" && !isExpired) {
        active++;
      } else if (status == "reserved" && !isExpired) {
        reserved++;
      } else if (status == "completed") {
        completed++;
      }
    }

    setState(() {
      activeCount = active;
      reservedCount = reserved;
      completedCount = completed;
      loadingStats = false;
    });
  }

  // ================= CONFIRM =================
  Future<void> _confirmDonation(String donationId) async {
    final donationRef = FirebaseFirestore.instance
        .collection("donations")
        .doc(donationId);

    await donationRef.update({
      "status": "completed",
      "completedAt": Timestamp.now(),
    });

    final snap = await donationRef.get();
    final data = snap.data() as Map<String, dynamic>;

    final restaurantId = data["restaurantId"];
    final ngoId = data["ngoId"];
    final title = data["title"] ?? "Donation";

    if (ngoId != null) {
      final chatRef = FirebaseFirestore.instance
          .collection("chats")
          .doc(donationId);

      final chatSnap = await chatRef.get();

      if (!chatSnap.exists) {
        await chatRef.set({
          "donationId": donationId,
          "restaurantId": restaurantId,
          "ngoId": ngoId,
          "participants": [restaurantId, ngoId],
          "lastMessage": 'Chat started for "$title"',
          "lastMessageAt": Timestamp.now(),
          "createdAt": Timestamp.now(),
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Donation marked as completed")),
    );

    _loadStats();
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FCMService.clearFCMToken();
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
    }
  }

  // ================= PAGES =================
  List<Widget> get _pages => [
    _homeView(),
    const RestaurantDonationsPage(),
    const RestaurantHistoryPage(),
    const ProfilePage(role: "restaurant"),
  ];

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Food4Need", style: TextStyle(color: Colors.white)),
        actions: [
          /// ✅ MESSAGE ICON WITH UNREAD BADGE (ONLY CHANGE)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: myUid)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadTotal = 0;

              if (snapshot.hasData) {
                for (var chat in snapshot.data!.docs) {
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chat.id)
                      .collection('messages')
                      .where('senderId', isNotEqualTo: myUid)
                      .get()
                      .then((msgs) {
                        for (var m in msgs.docs) {
                          final data = m.data() as Map<String, dynamic>;
                          final seenBy = List<String>.from(
                            data["seenBy"] ?? [],
                          );
                          if (!seenBy.contains(myUid)) {
                            unreadTotal++;
                          }
                        }
                      });
                }
              }

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatListPage()),
                      );
                    },
                  ),
                  if (unreadTotal > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          unreadTotal.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          PopupMenuButton(
            onSelected: (value) {
              if (value == "logout") _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: IndexedStack(index: _index, children: _pages),
      ),

      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xffd4a373),
              onPressed: () => Navigator.pushNamed(context, "/create-donation"),
              icon: const Icon(Icons.add),
              label: const Text("Donate Food"),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: const Color(0xff5a3825),
        unselectedItemColor: Colors.black87,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "My Donations",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // ================= HOME VIEW =================
  Widget _homeView() {
    final today = DateTime.now();
    final formattedDate = "${today.day}-${today.month}-${today.year}";

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
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
          const SizedBox(height: 4),
          Text(
            "Today: $formattedDate",
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 25),

          loadingStats
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard("Active", activeCount, Colors.blue),
                    _statCard("Reserved", reservedCount, Colors.orange),
                    _statCard("Completed", completedCount, Colors.green),
                  ],
                ),

          const SizedBox(height: 30),
          const Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff5a3825),
            ),
          ),
          const SizedBox(height: 8),
          _recentActivity(),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  // ================= RECENT ACTIVITY =================
  Widget _recentActivity() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("donations")
          .where("restaurantId", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("Loading...");

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("No recent activity yet.");

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final status = data["status"];
            final expiry = data["expiryAt"];

            final isExpired =
                expiry != null &&
                (expiry as Timestamp).toDate().isBefore(DateTime.now());

            if (isExpired && status != "completed") {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.fastfood, color: Color(0xffd4a373)),
                title: Text(data["title"] ?? ""),
                subtitle: Text("Status: $status"),
                trailing: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status == "reserved"
                        ? Colors.orange
                        : Colors.black54,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
