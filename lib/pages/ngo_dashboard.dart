import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import '../pages/profile_page.dart';
import '../pages/ngo_accepted_page.dart';
import '../pages/ngo_history_page.dart';
import '../services/fcm_service.dart';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  String _ngoName = "NGO Partner";
  bool _isLoading = true;
  int _currentIndex = 0;

  // Filters
  bool halalFilter = false;
  double maxDistance = 20;

  // Sorting
  String sortOption = "nearest";

  LatLng? ngoLoc;

  @override
  void initState() {
    super.initState();
    _loadNGOProfile();
    _loadNGOLocation();
  }

  // ================= NGO PROFILE =================
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
      _ngoName = snap.data()?["name"] ?? "NGO Partner";
    }

    setState(() => _isLoading = false);
  }

  // ================= NGO LOCATION =================
  Future<void> _loadNGOLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (snap.exists) {
      final data = snap.data();
      if (data?["latitude"] != null && data?["longitude"] != null) {
        ngoLoc = LatLng(data!["latitude"], data["longitude"]);
      }
    }
  }

  // ================= LOGOUT =================
  void _logout() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

    if (confirmed) {
      await FCMService.clearFCMToken();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
      }
    }
  }

  // ================= DISTANCE =================
  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ================= FILTER =================
  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool tempHalal = halalFilter;
        double tempMaxDistance = maxDistance;

        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            title: const Text("Filter Donations"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text("Halal Only"),
                  value: tempHalal,
                  onChanged: (v) => setDialogState(() => tempHalal = v!),
                ),
                Text("Max Distance: ${tempMaxDistance.toStringAsFixed(0)} km"),
                Slider(
                  min: 1,
                  max: 50,
                  divisions: 49,
                  value: tempMaxDistance,
                  onChanged: (v) => setDialogState(() => tempMaxDistance = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Apply"),
                onPressed: () {
                  setState(() {
                    halalFilter = tempHalal;
                    maxDistance = tempMaxDistance;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= SORT =================
  void _openSortDialog() {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Sort By"),
        children: [
          SimpleDialogOption(
            child: const Text("Nearest"),
            onPressed: () {
              setState(() => sortOption = "nearest");
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text("Latest"),
            onPressed: () {
              setState(() => sortOption = "latest");
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text("Largest Quantity"),
            onPressed: () {
              setState(() => sortOption = "quantity");
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _homePage(),
      const NGOAcceptedPage(),
      const NGOHistoryPage(),
      const ProfilePage(role: "ngo"),
    ];

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Food4Need", style: TextStyle(color: Colors.white)),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterDialog,
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _openSortDialog,
            ),
          ],
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
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xff5a3825),
        unselectedItemColor: Colors.black87,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: "Accepted",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // ================= HOME =================
  Widget _homePage() {
    return Padding(
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
          const SizedBox(height: 10),
          const Text("Available food donations"),
          const SizedBox(height: 15),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("donations")
                  .where("status", isEqualTo: "available")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final List<int> validIndexes = [];

                for (int i = 0; i < docs.length; i++) {
                  final d = docs[i].data() as Map<String, dynamic>;

                  // 🔥 ONLY CHANGE: SKIP EXPIRED DONATIONS
                  final expiry = d["expiryAt"];
                  if (expiry != null &&
                      (expiry as Timestamp).toDate().isBefore(DateTime.now())) {
                    // ✅ OPTION B: auto-mark expired
                    if (d["status"] == "reserved") {
                      FirebaseFirestore.instance
                          .collection("donations")
                          .doc(docs[i].id)
                          .update({
                            "status": "expired",
                            "expiredAt": DateTime.now(),
                          });
                    }
                    continue;
                  }

                  if (halalFilter && d["halal"] != true) continue;

                  if (ngoLoc != null) {
                    if (d["latitude"] == null || d["longitude"] == null)
                      continue;

                    final dist = calculateDistance(
                      ngoLoc!.latitude,
                      ngoLoc!.longitude,
                      d["latitude"],
                      d["longitude"],
                    );

                    if (dist > maxDistance) continue;
                  }

                  validIndexes.add(i);
                }

                if (validIndexes.isEmpty) {
                  return const Center(
                    child: Text(
                      "No donations match your filter 😕",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: validIndexes.length,
                  itemBuilder: (context, index) {
                    final i = validIndexes[index];
                    final d = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;

                    double? distanceKm;
                    if (ngoLoc != null &&
                        d["latitude"] != null &&
                        d["longitude"] != null) {
                      distanceKm = calculateDistance(
                        ngoLoc!.latitude,
                        ngoLoc!.longitude,
                        d["latitude"],
                        d["longitude"],
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xfffaedcd),
                          child: Icon(Icons.fastfood, color: Color(0xffd4a373)),
                        ),
                        title: Text(d["title"] ?? ""),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: d["halal"] == true
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                d["halal"] == true ? "Halal" : "Non-Halal",
                                style: TextStyle(
                                  color: d["halal"] == true
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Qty: ${d["quantity"]}"),
                            Text("Pickup: ${d["pickupTime"]}"),
                            if (distanceKm != null)
                              Text(
                                "Distance: ${distanceKm.toStringAsFixed(2)} km",
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffd4a373),
                          ),
                          child: const Text("View"),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              "/ngo-donation-details",
                              arguments: docId,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
