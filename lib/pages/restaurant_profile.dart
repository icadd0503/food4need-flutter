import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

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
    if (uid == null) return;

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

      // Parse operating hours string
      if (data["operatingHours"] != null) {
        final parts = data["operatingHours"].split(" - ");
        openTime = _parseTime(parts[0]);
        closeTime = _parseTime(parts[1]);
      }

      if (data["latitude"] != null && data["longitude"] != null) {
        selectedLocation = LatLng(data["latitude"], data["longitude"]);
      }
    }

    setState(() => loading = false);
  }

  TimeOfDay _parseTime(String time) {
    final dt = TimeOfDay.fromDateTime(
      DateTime.parse(
        "1970-01-01 ${time.replaceAll(" AM", "").replaceAll(" PM", "")}",
      ),
    );
    return dt;
  }

  // ================= PICK TIME =================
  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen
          ? (openTime ?? TimeOfDay.now())
          : (closeTime ?? TimeOfDay.now()),
    );

    if (picked != null) {
      setState(() {
        if (isOpen) {
          openTime = picked;
        } else {
          closeTime = picked;
        }
      });
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (selectedLocation == null || openTime == null || closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete location and operating hours"),
        ),
      );
      return;
    }

    setState(() => saving = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final hours =
        "${openTime!.format(context)} - ${closeTime!.format(context)}";

    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "address": addressController.text.trim(),
      "businessRegNo": businessRegNoController.text.trim(),
      "operatingHours": hours,
      "halal": halal,
      "latitude": selectedLocation!.latitude,
      "longitude": selectedLocation!.longitude,
    });

    setState(() => saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully")),
    );

    Navigator.pop(context);
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
            _input(nameController, "Restaurant Name", Icons.store),
            _input(phoneController, "Phone Number", Icons.phone),
            _input(addressController, "Address", Icons.location_on),
            _input(
              businessRegNoController,
              "Business Registration No",
              Icons.assignment,
            ),

            const SizedBox(height: 10),

            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                openTime == null
                    ? "Select Opening Time"
                    : "Open: ${openTime!.format(context)}",
              ),
              onTap: () => _pickTime(true),
            ),

            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                closeTime == null
                    ? "Select Closing Time"
                    : "Close: ${closeTime!.format(context)}",
              ),
              onTap: () => _pickTime(false),
            ),

            SwitchListTile(
              value: halal,
              title: const Text("Halal Food"),
              onChanged: (v) => setState(() => halal = v),
            ),

            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Pin Restaurant Location",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                onTap: (latLng) => setState(() => selectedLocation = latLng),
                markers: {
                  if (selectedLocation != null)
                    Marker(
                      markerId: const MarkerId("restaurant"),
                      position: selectedLocation!,
                      draggable: true,
                      onDragEnd: (p) => setState(() => selectedLocation = p),
                    ),
                },
              ),
            ),

            const SizedBox(height: 30),

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
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
