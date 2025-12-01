import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantProfile extends StatefulWidget {
  const RestaurantProfile({super.key});

  @override
  State<RestaurantProfile> createState() => _RestaurantProfileState();
}

class _RestaurantProfileState extends State<RestaurantProfile> {
  // Renamed stateC for clarity
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final closingTimeController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Dispose controllers to prevent memory leaks
  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    closingTimeController.dispose();
    super.dispose();
  }

  // 1. IMPROVED: Added try-catch for loading errors
  _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Handle case where user is not logged in
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final ref = FirebaseFirestore.instance.collection("users").doc(uid);
      final snap = await ref.get();

      if (snap.exists) {
        final data = snap.data()!;
        nameController.text = data["name"] ?? "";
        phoneController.text = data["phone"] ?? "";
        addressController.text = data["address"] ?? "";
        cityController.text = data["city"] ?? "";
        stateController.text = data["state"] ?? "";
        closingTimeController.text = data["closingTime"] ?? "";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 2. IMPROVED: Added try-catch for saving errors and better feedback
  _saveProfile() async {
    if (!mounted) return;
    setState(() => _saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": nameController.text,
        "phone": phoneController.text,
        "address": addressController.text,
        "city": cityController.text,
        "state": stateController.text,
        "closingTime": closingTimeController.text,
      });

      // Show success message (Snackbar is better than an inline text widget)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        // 3. IMPROVED: Navigate back immediately after success feedback
        Navigator.pop(context);
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // For back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Removed the inline 'message' Text widget as Snackbar is now used
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Restaurant Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: "Address"),
            ),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: "City"),
            ),
            TextField(
              controller: stateController,
              decoration: const InputDecoration(labelText: "State"),
            ),
            TextField(
              controller: closingTimeController,
              decoration: const InputDecoration(
                labelText: "Closing Time (e.g., 22:00)",
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  50,
                ), // Make button full width
                backgroundColor: const Color(0xffd4a373),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      "Save Changes",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
