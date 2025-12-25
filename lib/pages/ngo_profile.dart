import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class NGOProfile extends StatefulWidget {
  const NGOProfile({super.key});

  @override
  State<NGOProfile> createState() => _NGOProfileState();
}

class _NGOProfileState extends State<NGOProfile> {
  // COMMON
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  // NGO-SPECIFIC (🔥 THIS WAS MISSING)
  final TextEditingController ngoRegNoController = TextEditingController();
  final TextEditingController coverageAreaController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();

  bool saving = false;
  bool _initialized = false;

  LatLng? selectedLocation;
  GoogleMapController? mapController;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    ngoRegNoController.dispose();
    coverageAreaController.dispose();
    contactPersonController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a location")));
      return;
    }

    setState(() => saving = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      // COMMON
      "name": nameController.text.trim(),
      "phone": phoneController.text.trim(),
      "address": addressController.text.trim(),
      "city": cityController.text.trim(),
      "state": stateController.text.trim(),

      // NGO (✅ MATCH REGISTER & PROFILE)
      "ngoRegNo": ngoRegNoController.text.trim(),
      "coverageArea": coverageAreaController.text.trim(),
      "contactPerson": contactPersonController.text.trim(),

      // LOCATION
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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("NGO Profile"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>;

          /// INIT CONTROLLERS ONCE (SAFE)
          if (!_initialized) {
            nameController.text = data["name"] ?? "";
            phoneController.text = data["phone"] ?? "";
            addressController.text = data["address"] ?? "";
            cityController.text = data["city"] ?? "";
            stateController.text = data["state"] ?? "";

            ngoRegNoController.text = data["ngoRegNo"] ?? "";
            coverageAreaController.text = data["coverageArea"] ?? "";
            contactPersonController.text = data["contactPerson"] ?? "";

            if (data["latitude"] != null && data["longitude"] != null) {
              selectedLocation = LatLng(data["latitude"], data["longitude"]);
            }

            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _input(nameController, "NGO Name", Icons.apartment),
                _input(phoneController, "Phone Number", Icons.phone),
                _input(addressController, "Address", Icons.location_on),
                _input(cityController, "City", Icons.location_city),
                _input(stateController, "State", Icons.map),

                const SizedBox(height: 10),

                _input(ngoRegNoController, "NGO Registration No", Icons.badge),
                _input(
                  coverageAreaController,
                  "Coverage Area",
                  Icons.map_outlined,
                ),
                _input(contactPersonController, "Contact Person", Icons.person),

                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Pin NGO Location",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 260,
                  child: GoogleMap(
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onMapCreated: (controller) => mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target:
                          selectedLocation ?? const LatLng(5.4164, 100.3327),
                      zoom: 15,
                    ),
                    onTap: (latLng) {
                      setState(() => selectedLocation = latLng);
                    },
                    markers: {
                      if (selectedLocation != null)
                        Marker(
                          markerId: const MarkerId("ngo"),
                          position: selectedLocation!,
                          draggable: true,
                          onDragEnd: (newPos) {
                            setState(() => selectedLocation = newPos);
                          },
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
          );
        },
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
