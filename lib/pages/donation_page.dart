import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateDonationPage extends StatefulWidget {
  const CreateDonationPage({super.key});

  @override
  State<CreateDonationPage> createState() => _CreateDonationPageState();
}

class _CreateDonationPageState extends State<CreateDonationPage> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final qtyController = TextEditingController();

  TimeOfDay? pickupTime;

  bool loading = false;
  String message = "";
  bool isHalal = true;

  /// PICK PICKUP DEADLINE (TODAY)
  Future<void> _pickPickupTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => pickupTime = time);
    }
  }

  /// CREATE DONATION
  Future<void> createDonation() async {
    if (titleController.text.isEmpty ||
        qtyController.text.isEmpty ||
        pickupTime == null) {
      setState(() => message = "Please fill all required fields");
      return;
    }

    final quantity = int.tryParse(qtyController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => message = "Quantity must be a valid number");
      return;
    }

    setState(() {
      loading = true;
      message = "";
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    final userData = userDoc.data();

    if (userData == null ||
        userData["latitude"] == null ||
        userData["longitude"] == null) {
      setState(() {
        message = "Please set your restaurant location first.";
        loading = false;
      });
      return;
    }

    final now = DateTime.now();

    /// SINGLE CUTOFF TIME
    final pickupDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      pickupTime!.hour,
      pickupTime!.minute,
    );

    /// SAFETY CHECK: must be in the future
    if (pickupDateTime.isBefore(now)) {
      setState(() {
        message = "Pickup time must be in the future.";
        loading = false;
      });
      return;
    }

    await FirebaseFirestore.instance.collection("donations").add({
      "title": titleController.text.trim(),
      "description": descController.text.trim(),
      "quantity": quantity,
      "halal": isHalal,

      // SINGLE TIME SOURCE OF TRUTH
      "pickupTimestamp": pickupDateTime, // pickup & accept until
      "expiryAt": pickupDateTime, // same as pickup

      "pickupTime":
          "${pickupTime!.hour.toString().padLeft(2, '0')}:${pickupTime!.minute.toString().padLeft(2, '0')}",

      // LOCATION
      "restaurantId": uid,
      "latitude": userData["latitude"],
      "longitude": userData["longitude"],

      // STATUS
      "status": "available",
      "createdAt": DateTime.now(),
    });

    setState(() {
      loading = false;
      message = "Donation created successfully!";
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      appBar: AppBar(
        backgroundColor: const Color(0xffd4a373),
        title: const Text("Create Donation"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  message,
                  style: TextStyle(
                    color: message.contains("success")
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),

            _input(titleController, "Food Title"),
            _input(descController, "Description (Optional)"),
            _input(qtyController, "Quantity", keyboard: TextInputType.number),

            const SizedBox(height: 12),

            /// PICKUP / EXPIRY TIME
            ListTile(
              title: Text(
                pickupTime == null
                    ? "Select Pickup By (Accept Until)"
                    : "Pickup & Accept Until: ${pickupTime!.format(context)}",
              ),
              subtitle: const Text(
                "NGOs must accept and collect the food by this time",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: _pickPickupTime,
            ),

            const SizedBox(height: 15),

            /// HALAL SWITCH
            Row(
              children: [
                const Text(
                  "Halal Food",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: isHalal,
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  onChanged: (v) => setState(() => isHalal = v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : createDonation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd4a373),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Submit Donation",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
