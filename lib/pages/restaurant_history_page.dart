import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantHistoryPage extends StatelessWidget {
  const RestaurantHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      color: const Color(0xfffefae0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("donations")
            .where("restaurantId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No donation history yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          // FILTER: completed OR expired
          final historyDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final status = data["status"];
            final expiry = data["expiryAt"];

            final isExpired =
                expiry != null &&
                (expiry as Timestamp).toDate().isBefore(DateTime.now());

            return status == "completed" || isExpired;
          }).toList();

          if (historyDocs.isEmpty) {
            return const Center(
              child: Text(
                "No completed or expired donations yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: historyDocs.length,
            itemBuilder: (context, index) {
              final donation =
                  historyDocs[index].data() as Map<String, dynamic>;

              final halal = donation["halal"] == true;
              final status = donation["status"];
              final completedAt = donation["completedAt"] != null
                  ? (donation["completedAt"] as Timestamp).toDate()
                  : null;

              bool isExpired = false;
              DateTime? expiryAt;

              if (donation["expiryAt"] != null) {
                expiryAt = (donation["expiryAt"] as Timestamp).toDate();
                if (expiryAt.isBefore(DateTime.now()) &&
                    status != "completed") {
                  isExpired = true;
                }
              }

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
                    Text(
                      donation["title"] ?? "",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffd4a373),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.fastfood,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text("Qty: ${donation["quantity"]}"),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        _chip("Pickup: ${donation["pickupTime"]}"),
                        const SizedBox(width: 6),
                        _chip(halal ? "Halal" : "Non-Halal"),
                      ],
                    ),

                    const Divider(height: 22),

                    Row(
                      children: [
                        Icon(
                          isExpired ? Icons.warning : Icons.check_circle,
                          color: isExpired ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExpired ? "EXPIRED" : "COMPLETED",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    if (isExpired && expiryAt != null)
                      Text(
                        "Expired at: ${expiryAt.toLocal()}",
                        style: const TextStyle(color: Colors.black54),
                      ),

                    if (!isExpired && completedAt != null)
                      Text(
                        "Completed at: ${completedAt.toLocal()}",
                        style: const TextStyle(color: Colors.black54),
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

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfffaedcd),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xff5a3825),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
