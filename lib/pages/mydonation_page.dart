import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantDonationsPage extends StatelessWidget {
  const RestaurantDonationsPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case "available":
        return Colors.blue;
      case "reserved":
        return Colors.orange;
      case "accepted":
      case "confirmed":
        return Colors.teal;
      case "completed":
        return Colors.green;
      case "expired":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "available":
        return Icons.access_time;
      case "reserved":
        return Icons.bookmark;
      case "accepted":
      case "confirmed":
        return Icons.local_shipping;
      case "completed":
        return Icons.check_circle;
      case "expired":
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  bool _isActiveStatus(String status) {
    return status == "available" ||
        status == "reserved" ||
        status == "accepted" ||
        status == "confirmed";
  }

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

          final docs = snapshot.data!.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final status = d["status"] ?? "available";
            return _isActiveStatus(status);
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No active donations 🍽️",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final donation = docs[i].data() as Map<String, dynamic>;
              final docId = docs[i].id;

              final halal = donation["halal"] == true;
              final status = donation["status"] ?? "available";

              /// ✅ ONLY CHANGE: AUTO-EXPIRE
              if (status == "available" && donation["expiryAt"] != null) {
                final expiry = (donation["expiryAt"] as Timestamp).toDate();

                if (expiry.isBefore(DateTime.now())) {
                  FirebaseFirestore.instance
                      .collection("donations")
                      .doc(docId)
                      .update({
                        "status": "expired",
                        "expiredAt": Timestamp.now(),
                      });

                  return const SizedBox.shrink();
                }
              }

              bool isExpired = false;
              String expiryText = "";

              if (donation["expiryAt"] != null) {
                final expiry = (donation["expiryAt"] as Timestamp).toDate();
                final diff = expiry.difference(DateTime.now());

                if (diff.isNegative && status == "available") {
                  isExpired = true;
                  expiryText = "Expired";
                } else if (!diff.isNegative) {
                  expiryText =
                      "Expires in ${diff.inHours}h ${diff.inMinutes % 60}m";
                }
              }

              final canDelete = status == "available" || status == "expired";
              final canEdit = status == "available";

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: halal
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              halal ? "HALAL" : "NON-HALAL",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: halal ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  donation["title"] ?? "",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text("Quantity: ${donation["quantity"]}"),
                                Text("Pickup Time: ${donation["pickupTime"]}"),
                                if (expiryText.isNotEmpty)
                                  Text(
                                    expiryText,
                                    style: TextStyle(
                                      color: isExpired
                                          ? Colors.red
                                          : Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == "edit") {
                                Navigator.pushNamed(
                                  context,
                                  "/edit-donation",
                                  arguments: docId,
                                );
                              }

                              if (value == "delete") {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Delete Donation"),
                                    content: const Text(
                                      "Are you sure you want to delete this donation?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection("donations")
                                      .doc(docId)
                                      .delete();
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              if (canEdit)
                                const PopupMenuItem(
                                  value: "edit",
                                  child: Text("Edit Donation"),
                                ),
                              if (canDelete)
                                const PopupMenuItem(
                                  value: "delete",
                                  child: Text(
                                    "Delete Donation",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(status),
                              color: _statusColor(status),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (status == "reserved") ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () async {
                                  final donationRef = FirebaseFirestore.instance
                                      .collection("donations")
                                      .doc(docId);

                                  final snap = await donationRef.get();
                                  final data =
                                      snap.data() as Map<String, dynamic>;

                                  final restaurantId =
                                      FirebaseAuth.instance.currentUser!.uid;
                                  final ngoId = data["ngoId"];

                                  await donationRef.update({
                                    "status": "confirmed",
                                  });

                                  final chatRef = FirebaseFirestore.instance
                                      .collection("chats")
                                      .doc(docId);

                                  final chatSnap = await chatRef.get();

                                  if (!chatSnap.exists) {
                                    await chatRef.set({
                                      "donationId": docId,
                                      "restaurantId": restaurantId,
                                      "ngoId": ngoId,
                                      "participants": [restaurantId, ngoId],
                                      "lastMessage":
                                          "Chat started for this donation",
                                      "lastMessageAt": Timestamp.now(),
                                      "createdAt": Timestamp.now(),
                                    });
                                  }
                                },
                                child: const Text("Accept"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection("donations")
                                      .doc(docId)
                                      .update({
                                        "status": "available",
                                        "ngoId": FieldValue.delete(),
                                        "reservedBy": FieldValue.delete(),
                                      });
                                },
                                child: const Text("Reject"),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (status == "confirmed") ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Waiting for NGO to mark as Delivered",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
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
