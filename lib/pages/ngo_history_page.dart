import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
            .where("ngoId", isEqualTo: uid)
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
                margin: const EdgeInsets.only(bottom: 14),
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
                    /// ================= TITLE =================
                    Text(
                      data["title"] ?? "Donation",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffd4a373),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// ================= RESTAURANT =================
                    Row(
                      children: [
                        const Icon(Icons.store, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data["restaurantName"] ?? "Restaurant",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// ================= INFO BADGES =================
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _badge("Quantity: ${data["quantity"]}"),
                        _badge("Pickup: ${data["pickupTime"]}"),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// ================= HALAL STATUS =================
                    _halalBadge(data["halal"] == true),

                    const Divider(height: 28),

                    /// ================= COMPLETION DATE =================
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          completedAt != null
                              ? "Completed on ${DateFormat('dd MMM yyyy, hh:mm a').format(completedAt)}"
                              : "Completed",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  /// ================= SMALL INFO BADGE =================
  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfffaedcd),
        borderRadius: BorderRadius.circular(10),
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

  /// ================= HALAL / NON-HALAL BADGE =================
  Widget _halalBadge(bool halal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: halal ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            halal ? Icons.verified : Icons.warning,
            size: 16,
            color: halal ? Colors.green[800] : Colors.red[800],
          ),
          const SizedBox(width: 6),
          Text(
            halal ? "Halal" : "Non-Halal",
            style: TextStyle(
              color: halal ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
