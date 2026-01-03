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
    if (uid == null) {
      // If there is no signed-in user, stop loading to avoid an infinite spinner
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

      // Prefer explicit opening/closing time fields (HH:mm) if present
      if (data["openingTime"] != null && data["closingTime"] != null) {
        try {
          openTime = _parseTime(data["openingTime"].toString());
          closeTime = _parseTime(data["closingTime"].toString());
        } catch (e) {
          // ignore parse errors and fall back to operatingHours
        }
      } else if (data["operatingHours"] != null) {
        try {
          final parts = (data["operatingHours"] as String).split(" - ");
          if (parts.length >= 2) {
            openTime = _parseTime(parts[0]);
            closeTime = _parseTime(parts[1]);
          }
        } catch (e) {
          // ignore parse errors and leave times null
        }
      }

      if (data["latitude"] != null && data["longitude"] != null) {
        final lat = data["latitude"];
        final lng = data["longitude"];
        if (lat is num && lng is num) {
          selectedLocation = LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    }

    setState(() => loading = false);
  }

  TimeOfDay _parseTime(String time) {
    final t = time.trim();
    final reg = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?');
    final match = reg.firstMatch(t);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3);
      if (ampm != null) {
        final isPm = ampm.toLowerCase().contains('pm');
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour % 24, minute: minute);
    }
    // fallback: try parse as HH:mm
    try {
      final parts = t.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour % 24, minute: minute % 60);
      }
    } catch (_) {}
    return TimeOfDay.now();
  }

  String _timeTo24String(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
    // Provide specific validation messages so user knows why save didn't happen
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pin restaurant location on the map")),
      );
      return;
    }
    if (openTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select opening time")),
      );
      return;
    }
    if (closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select closing time")),
      );
      return;
    }

    setState(() => saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No signed-in user found")),
      );
      return;
    }

    final hours = "${openTime!.format(context)} - ${closeTime!.format(context)}";
    final opening24 = _timeTo24String(openTime!);
    final closing24 = _timeTo24String(closeTime!);

    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "address": addressController.text.trim(),
        "businessRegNo": businessRegNoController.text.trim(),
        "operatingHours": hours,
        "openingTime": opening24,
        "closingTime": closing24,
        "halal": halal,
        "latitude": selectedLocation!.latitude,
        "longitude": selectedLocation!.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );

      // Close the page after successful update
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      // Log to console in debug mode and show an error to the user
      if (kDebugMode) print("Failed to update profile: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update profile: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
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