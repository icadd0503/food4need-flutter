import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NGOHistoryPage extends StatelessWidget {
  const NGOHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text(
          "Completed Donations",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("donations")
            .where("status", isEqualTo: "completed")
            .where("ngoId", isEqualTo: uid) // ✅ MATCH NGOAcceptedPage
            .orderBy("completedAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No completed donations yet.\nStart helping to see history here!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final completedAt = (data["completedAt"] as Timestamp?)?.toDate();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// TITLE
                    Text(
                      data["title"] ?? "",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffd4a373),
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// RESTAURANT (SAFE FALLBACK)
                    Row(
                      children: [
                        const Icon(Icons.store, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data["restaurantName"] ?? "Restaurant",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _badge("Qty: ${data["quantity"]}"),
                        const SizedBox(width: 6),
                        _badge("Pickup: ${data["pickupTime"]}"),
                      ],
                    ),

                    const SizedBox(height: 10),

                    _halalBadge(data["halal"] == true),

                    const Divider(height: 24),

                    /// COMPLETION DATE
                    Text(
                      completedAt != null
                          ? "Completed: ${completedAt.toLocal()}"
                          : "Completed",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfffaedcd),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff5a3825),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _halalBadge(bool halal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: halal ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        halal ? "Halal" : "Non-Halal",
        style: TextStyle(
          color: halal ? Colors.green[800] : Colors.red[800],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
