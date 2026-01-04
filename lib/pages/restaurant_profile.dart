import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';

class RestaurantProfile extends StatefulWidget {
  const RestaurantProfile({super.key});

  @override
  State<RestaurantProfile> createState() => _RestaurantProfileState();
}

class _RestaurantProfileState extends State<RestaurantProfile> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController businessRegNoController = TextEditingController();

  TimeOfDay? openTime;
  TimeOfDay? closeTime;

  bool halal = true;
  bool loading = true;
  bool saving = false;

  LatLng? selectedLocation;
  GoogleMapController? mapController;

  // ===== PROFILE IMAGE =====
  File? profileImage;
  String? profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    businessRegNoController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  // ================= LOAD PROFILE =================
  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => loading = false);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (snap.exists) {
      final data = snap.data()!;
      nameController.text = data["name"] ?? "";
      phoneController.text = data["phone"] ?? "";
      addressController.text = data["address"] ?? "";
      businessRegNoController.text = data["businessRegNo"] ?? "";
      halal = data["halal"] == true;
      profileImageUrl = data["profileImageUrl"];

      if (data["openingTime"] != null && data["closingTime"] != null) {
        openTime = _parseTime(data["openingTime"]);
        closeTime = _parseTime(data["closingTime"]);
      }

      if (data["latitude"] != null && data["longitude"] != null) {
        selectedLocation = LatLng(
          data["latitude"].toDouble(),
          data["longitude"].toDouble(),
        );
      }
    }

    setState(() => loading = false);
  }

  // ================= AUTO FILL ADDRESS =================
  Future<void> _fillAddressFromMap(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        setState(() {
          addressController.text = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((e) => e != null && e!.isNotEmpty).join(", ");
        });
      }
    } catch (e) {
      if (kDebugMode) print("Geocoding error: $e");
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _timeTo24String(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  // ================= PICK PROFILE IMAGE =================
  Future<void> _pickProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked == null) return;

    setState(() => profileImage = File(picked.path));

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child(uid)
          .child("profile.jpg");

      await ref.putFile(profileImage!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "profileImageUrl": url,
      });

      setState(() => profileImageUrl = url);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile picture updated")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (selectedLocation == null || openTime == null || closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    setState(() => saving = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "address": addressController.text.trim(),
        "businessRegNo": businessRegNoController.text.trim(),
        "openingTime": _timeTo24String(openTime!),
        "closingTime": _timeTo24String(closeTime!),
        "halal": halal,
        "latitude": selectedLocation!.latitude,
        "longitude": selectedLocation!.longitude,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile updated")));

      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) print(e);
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Restaurant Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage!)
                    : (profileImageUrl != null
                              ? NetworkImage(profileImageUrl!)
                              : null)
                          as ImageProvider?,
                child: profileImage == null && profileImageUrl == null
                    ? const Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.white70,
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            _input(nameController, "Restaurant Name", Icons.store),
            _input(phoneController, "Phone Number", Icons.phone),
            _input(
              addressController,
              "Address (auto-filled)",
              Icons.location_on,
            ),
            _input(
              businessRegNoController,
              "Business Reg No",
              Icons.assignment,
            ),

            ListTile(
              title: Text(
                openTime == null
                    ? "Select Opening Time"
                    : "Open: ${openTime!.format(context)}",
              ),
              onTap: () => _pickTime(true),
            ),
            ListTile(
              title: Text(
                closeTime == null
                    ? "Select Closing Time"
                    : "Close: ${closeTime!.format(context)}",
              ),
              onTap: () => _pickTime(false),
            ),

            SwitchListTile(
              title: const Text("Halal Food"),
              value: halal,
              onChanged: (v) => setState(() => halal = v),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 260,
              child: GoogleMap(
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                initialCameraPosition: CameraPosition(
                  target: selectedLocation ?? const LatLng(5.4164, 100.3327),
                  zoom: 15,
                ),
                onTap: (p) async {
                  setState(() => selectedLocation = p);
                  await _fillAddressFromMap(p);
                },
                markers: selectedLocation == null
                    ? {}
                    : {
                        Marker(
                          markerId: const MarkerId("restaurant"),
                          position: selectedLocation!,
                        ),
                      },
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text("Auto fill address from map"),
              onPressed: selectedLocation == null
                  ? null
                  : () => _fillAddressFromMap(selectedLocation!),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffd4a373),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Profile",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen
          ? (openTime ?? TimeOfDay.now())
          : (closeTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() => isOpen ? openTime = picked : closeTime = picked);
    }
  }

  Widget _input(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
