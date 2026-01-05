import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NGOAcceptedPage extends StatelessWidget {
  const NGOAcceptedPage({super.key});

  DateTime? _buildPickupDateTime(Timestamp createdAt, String pickupTime) {
    try {
      final baseDate = createdAt.toDate();

      final time = pickupTime.toUpperCase().trim(); // e.g. 7:00 PM
      final parts = time.split(" ");
      final hm = parts[0].split(":");

      int hour = int.parse(hm[0]);
      int minute = int.parse(hm[1]);
      final period = parts[1];

      if (period == "PM" && hour != 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;

      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Donations from Restaurants"),
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
                "No active donations right now",
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

              /// ===============================
              /// AUTO-DELIVER IF NGO FORGOT TO CLICK
              /// ===============================
              if (status == "confirmed" &&
                  donation["pickupTime"] != null &&
                  donation["createdAt"] != null &&
                  donation["completedAt"] == null) {
                final pickupDateTime = _buildPickupDateTime(
                  donation["createdAt"],
                  donation["pickupTime"],
                );

                if (pickupDateTime != null) {
                  // ⏱ Grace period after pickup time
                  final autoCompleteTime = pickupDateTime.add(
                    const Duration(minutes: 30),
                  );

                  if (DateTime.now().isAfter(autoCompleteTime)) {
                    FirebaseFirestore.instance
                        .collection("donations")
                        .doc(docId)
                        .update({
                          "status": "completed",
                          "completedAt": DateTime.now(),
                        });

                    FirebaseFirestore.instance
                        .collection("chats")
                        .doc(docId)
                        .update({
                          "donationStatus": "completed",
                          "lastMessage":
                              "Donation automatically marked as delivered",
                          "lastMessageAt": Timestamp.now(),
                        });

                    // Remove card immediately from UI
                    return const SizedBox.shrink();
                  }
                }
              }

              /// ===============================
              /// AUTO-EXPIRE RESERVED
              /// ===============================
              if (status == "reserved" && donation["expiryAt"] != null) {
                final expiry = (donation["expiryAt"] as Timestamp).toDate();

                if (expiry.isBefore(DateTime.now())) {
                  FirebaseFirestore.instance
                      .collection("donations")
                      .doc(docId)
                      .update({
                        "status": "expired",
                        "expiredAt": DateTime.now(),
                      });

                  return const SizedBox.shrink();
                }
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
                        "Pickup Time: ${donation["pickupTime"]}",
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 8),

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

                      const SizedBox(height: 14),

                      Row(
                        children: [
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
                                  await FirebaseFirestore.instance
                                      .collection("chats")
                                      .doc(docId)
                                      .update({
                                        "donationStatus": "completed",
                                        "lastMessage": "Donation completed",
                                        "lastMessageAt": Timestamp.now(),
                                      });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Donation marked as delivered",
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Delivered",
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
