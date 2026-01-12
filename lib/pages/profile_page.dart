import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final profileImageUrl = data["profileImageUrl"];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              /// ================= AVATAR + EDIT PICTURE =================
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _changeProfilePicture(context),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xffd4a373),
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text("Edit Picture"),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xffd4a373),
                      ),
                      onPressed: () => _changeProfilePicture(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// ================= PROFILE INFO =================
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
                _info("Operating Hours", _formatOperatingHours(data)),
                _info("Halal", data["halal"] == true ? "Yes" : "No"),
              ],

              if (role == "ngo") ...[
                _info("NGO Registration No", data["ngoRegNo"] ?? "Not set"),
                _info("Coverage Area", data["coverageArea"] ?? "Not set"),
                _info("Contact Person", data["contactPerson"] ?? "Not set"),
              ],

              const SizedBox(height: 25),

              /// ================= EDIT FULL PROFILE =================
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

  // ================= CHANGE PROFILE PICTURE =================
  Future<void> _changeProfilePicture(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final file = File(picked.path);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child(uid)
          .child("profile.jpg");

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "profileImageUrl": url,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile picture updated")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    }
  }

  // ================= FORMAT OPERATING HOURS =================
  String _formatOperatingHours(Map<String, dynamic> data) {
    final opening = data["openingTime"];
    final closing = data["closingTime"];

    if (opening == null || closing == null) {
      return "Not set";
    }

    return "$opening - $closing";
  }

  // ================= INFO ROW =================
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
