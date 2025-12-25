import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  final String role; // "restaurant" or "ngo"

  const ProfilePage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      color: const Color(0xfffefae0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(), // 🔥 CHANGED HERE
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              /// AVATAR
              Center(
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xffd4a373),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _info(
                role == "restaurant" ? "Restaurant Name" : "NGO Name",
                data["name"] ?? "",
              ),
              _info("Email", data["email"] ?? ""),
              _info("Phone", data["phone"] ?? "Not set"),
              _info("Address", data["address"] ?? "Not set"),

              if (role == "restaurant") ...[
                _info(
                  "Business Registration No",
                  data["businessRegNo"] ?? "Not set",
                ),
                _info("Operating Hours", data["operatingHours"] ?? "Not set"),
                _info("Halal", data["halal"] == true ? "Yes" : "No"),
              ],

              if (role == "ngo") ...[
                _info("NGO Registration No", data["ngoRegNo"] ?? "Not set"),
                _info("Coverage Area", data["coverageArea"] ?? "Not set"),
                _info("Contact Person", data["contactPerson"] ?? "Not set"),
              ],

              const SizedBox(height: 25),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffd4a373),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    role == "restaurant"
                        ? "/restaurant-profile-edit"
                        : "/ngo-profile-edit",
                  );
                },
                child: const Text("Edit Profile"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black45)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
