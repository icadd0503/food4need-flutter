import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NGOAcceptedPage extends StatelessWidget {
  const NGOAcceptedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Accepted Donations"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("donations")
            .where("ngoId", isEqualTo: uid)
            .where("status", whereIn: ["reserved", "confirmed"])
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
                "No accepted donations yet.",
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final donation = docs[i].data() as Map<String, dynamic>;
              final docId = docs[i].id;
              final status = donation["status"];

              // ✅ OPTION B: AUTO-MARK EXPIRED
              final expiry = donation["expiryAt"];
              if (status == "reserved" &&
                  expiry != null &&
                  (expiry as Timestamp).toDate().isBefore(DateTime.now())) {
                FirebaseFirestore.instance
                    .collection("donations")
                    .doc(docId)
                    .update({"status": "expired", "expiredAt": DateTime.now()});

                return const SizedBox.shrink(); // hide expired
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
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

                      Text(
                        "Pickup By: ${donation["pickupTime"]}",
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 6),

                      Chip(
                        label: Text(
                          status == "reserved"
                              ? "Waiting for restaurant confirmation"
                              : "Confirmed by restaurant",
                        ),
                        backgroundColor: status == "reserved"
                            ? Colors.orange[200]
                            : Colors.green[200],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          /// DETAILS BUTTON
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffd4a373),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  "/ngo-donation-details",
                                  arguments: docId,
                                );
                              },
                              child: const Text("Details"),
                            ),
                          ),

                          const SizedBox(width: 10),

                          /// COLLECTED BUTTON (ONLY IF CONFIRMED)
                          if (status == "confirmed")
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection("donations")
                                      .doc(docId)
                                      .update({
                                        "status": "completed",
                                        "completedAt": DateTime.now(),
                                      });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Donation marked as collected",
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Collected",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
