import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String filter = "all"; // all | pending | approved

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          /// FILTER
          DropdownButton<String>(
            value: filter,
            dropdownColor: const Color(0xffd4a373),
            underline: const SizedBox(),
            iconEnabledColor: Colors.white,
            items: const [
              DropdownMenuItem(value: "all", child: Text("All")),
              DropdownMenuItem(value: "pending", child: Text("Pending")),
              DropdownMenuItem(value: "approved", child: Text("Approved")),
            ],
            onChanged: (value) => setState(() => filter = value!),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users =
              snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                if (doc.id == currentUid) return false;
                if (data["role"] == "admin") return false;

                final approved = data["approved"] ?? false;
                if (filter == "pending") return !approved;
                if (filter == "approved") return approved;
                return true;
              }).toList()..sort((a, b) {
                final aApproved =
                    (a.data() as Map<String, dynamic>)["approved"] ?? false;
                final bApproved =
                    (b.data() as Map<String, dynamic>)["approved"] ?? false;
                return aApproved == bApproved ? 0 : (aApproved ? 1 : -1);
              });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: users.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final approved = data["approved"] ?? false;
              final role = data["role"];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// NAME
                      Text(
                        data["name"] ?? "",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(data["email"] ?? ""),
                      Text("Role: ${role.toString().toUpperCase()}"),

                      const SizedBox(height: 8),

                      /// STATUS BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: approved
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          approved ? "Approved" : "Pending Approval",
                          style: TextStyle(
                            color: approved ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// ROLE-SPECIFIC DETAILS
                      if (role == "restaurant") ...[
                        Text(
                          "Business Reg No: ${data["businessRegNo"] ?? "-"}",
                        ),
                        Text(
                          "Operating Hours: ${data["operatingHours"] ?? "-"}",
                        ),
                        Text("Halal: ${data["halal"] == true ? "Yes" : "No"}"),
                      ],

                      if (role == "ngo") ...[
                        Text("NGO Reg No: ${data["ngoRegNo"] ?? "-"}"),
                        Text("Coverage Area: ${data["coverageArea"] ?? "-"}"),
                        Text("Contact Person: ${data["contactPerson"] ?? "-"}"),
                      ],

                      const SizedBox(height: 12),

                      /// ACTIONS
                      if (!approved)
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(doc.id)
                                    .update({"approved": true});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text("Approve"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(doc.id)
                                    .delete();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Reject"),
                            ),
                          ],
                        ),

                      if (approved)
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: role,
                              items: const [
                                DropdownMenuItem(
                                  value: "restaurant",
                                  child: Text("Restaurant"),
                                ),
                                DropdownMenuItem(
                                  value: "ngo",
                                  child: Text("NGO"),
                                ),
                              ],
                              onChanged: (value) {
                                FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(doc.id)
                                    .update({"role": value});
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(doc.id)
                                    .delete();
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
