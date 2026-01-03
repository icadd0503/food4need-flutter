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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No donations yet 😕",
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
              String status = donation["status"] ?? "available";

              final ngoId = donation["ngoId"] ?? donation["reservedBy"];

              // ===== EXPIRY LOGIC =====
              bool isExpired = false;
              String expiryText = "";

              if (donation["expiryAt"] != null) {
                final expiry = (donation["expiryAt"] as Timestamp).toDate();
                final diff = expiry.difference(DateTime.now());

                if (diff.isNegative && status == "available") {
                  isExpired = true;
                  status = "expired";
                  expiryText = "Expired";
                } else if (!diff.isNegative) {
                  expiryText =
                      "Expires in ${diff.inHours}h ${diff.inMinutes % 60}m";
                }
              }

              final canDelete = status == "available" || status == "expired";
              final canEdit = status == "available";

              return Dismissible(
                key: Key(docId),
                direction: canDelete
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                confirmDismiss: (_) async {
                  if (!canDelete) return false;

                  return await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Donation"),
                      content: const Text(
                        "Are you sure you want to delete this donation?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  FirebaseFirestore.instance
                      .collection("donations")
                      .doc(docId)
                      .delete();
                },
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// HALAL BADGE
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

                        /// DETAILS
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

                              const SizedBox(height: 10),

                              /// STATUS BADGE
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

                              /// 🧑 NGO INFO
                              if (ngoId != null &&
                                  status != "available" &&
                                  status != "expired") ...[
                                const SizedBox(height: 12),
                                FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection("users")
                                      .doc(ngoId)
                                      .get(),
                                  builder: (context, ngoSnap) {
                                    if (!ngoSnap.hasData) {
                                      return const Text("Loading NGO info...");
                                    }

                                    final ngo =
                                        ngoSnap.data!.data()
                                            as Map<String, dynamic>?;

                                    if (ngo == null) {
                                      return const Text("NGO info unavailable");
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Accepted By NGO",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff5a3825),
                                          ),
                                        ),
                                        Text("Name: ${ngo["name"] ?? "-"}"),
                                        Text("Phone: ${ngo["phone"] ?? "-"}"),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        /// MENU (EDIT KEPT)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == "edit") {
                              Navigator.pushNamed(
                                context,
                                "/edit-donation",
                                arguments: docId,
                              );
                            }
                          },
                          itemBuilder: (_) => canEdit
                              ? const [
                                  PopupMenuItem(
                                    value: "edit",
                                    child: Text("Edit Donation"),
                                  ),
                                ]
                              : const [],
                        ),
                      ],
                    ),
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