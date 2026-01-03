import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class NGODonationDetails extends StatefulWidget {
  final String donationId;

  const NGODonationDetails({super.key, required this.donationId});

  @override
  State<NGODonationDetails> createState() => _NGODonationDetailsState();
}

class _NGODonationDetailsState extends State<NGODonationDetails> {
  Map<String, dynamic>? donation;
  Map<String, dynamic>? restaurant;

  bool loading = true;
  bool accepting = false;

  LatLng? restaurantLoc;
  LatLng? ngoLoc;
  double? distanceKm;

  @override
  void initState() {
    super.initState();
    loadDonation();
  }

  Future<void> loadDonation() async {
    final snap = await FirebaseFirestore.instance
        .collection("donations")
        .doc(widget.donationId)
        .get();

    donation = snap.data();

    if (donation == null) {
      setState(() => loading = false);
      return;
    }

    final restDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(donation!["restaurantId"])
        .get();

    restaurant = restDoc.data();

    if (donation!["latitude"] != null && donation!["longitude"] != null) {
      restaurantLoc = LatLng(donation!["latitude"], donation!["longitude"]);
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ngoSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (ngoSnap.exists &&
        ngoSnap.data()?["latitude"] != null &&
        ngoSnap.data()?["longitude"] != null &&
        restaurantLoc != null) {
      ngoLoc = LatLng(
        ngoSnap.data()!["latitude"],
        ngoSnap.data()!["longitude"],
      );

      distanceKm = calculateDistance(
        restaurantLoc!.latitude,
        restaurantLoc!.longitude,
        ngoLoc!.latitude,
        ngoLoc!.longitude,
      );
    }

    setState(() => loading = false);
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg(lat1)) * cos(_deg(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg(double deg) => deg * (pi / 180);

  Future<void> acceptDonation() async {
    if (donation == null) return;

    setState(() => accepting = true);

    final donationRef = FirebaseFirestore.instance
        .collection("donations")
        .doc(widget.donationId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(donationRef);

        if (!snap.exists) throw Exception("Donation not found");
        if (snap["status"] != "available") {
          throw Exception("Already reserved");
        }

        transaction.update(donationRef, {
          "status": "reserved",
          "ngoId": FirebaseAuth.instance.currentUser!.uid,
          "acceptedAt": Timestamp.now(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donation reserved successfully")),
      );

      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donation already reserved")),
      );
    } finally {
      setState(() => accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (donation == null) {
      return const Scaffold(body: Center(child: Text("Donation not found")));
    }

    final halal = donation!["halal"] == true;
    final status = donation!["status"];
    final restName = restaurant?["name"] ?? "Restaurant";
    final restPhone = restaurant?["phone"] ?? "Not provided";

    final String? description = donation!["description"]?.toString().trim();

    String expiryText = "N/A";
    if (donation!["expiryAt"] != null) {
      final expiry = (donation!["expiryAt"] as Timestamp).toDate();
      final diff = expiry.difference(DateTime.now());
      expiryText = diff.isNegative
          ? "Expired"
          : "${diff.inHours}h ${diff.inMinutes % 60}m";
    }

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Donation Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              donation!["title"] ?? "",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xffd4a373),
              ),
            ),
            const SizedBox(height: 6),
            Text("From: $restName", style: const TextStyle(fontSize: 18)),

            /// DESCRIPTION (OPTIONAL)
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Description",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xff5a3825),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(description, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 15),

            /// INFO CARD
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow("Quantity", "${donation!["quantity"]}"),
                    _infoRow("Pickup Time", donation!["pickupTime"]),
                    _infoRow("Expires In", expiryText),
                    _infoRow("Status", status),
                    _infoRow("Phone", restPhone),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(halal ? "Halal" : "Non-Halal"),
                        backgroundColor: halal
                            ? Colors.green[100]
                            : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (distanceKm != null)
              Text(
                "Distance: ${distanceKm!.toStringAsFixed(2)} km",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

            const SizedBox(height: 15),

            if (restaurantLoc != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 280,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: restaurantLoc!,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("restaurant"),
                        position: restaurantLoc!,
                      ),
                    },
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
              ),

            const SizedBox(height: 25),

            if (status == "available" && expiryText != "Expired")
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: accepting ? null : acceptDonation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffd4a373),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  label: accepting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Accept Donation",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}