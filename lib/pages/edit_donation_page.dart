import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditDonationPage extends StatefulWidget {
  const EditDonationPage({super.key});

  @override
  State<EditDonationPage> createState() => _EditDonationPageState();
}

class _EditDonationPageState extends State<EditDonationPage> {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final qtyController = TextEditingController();

  TimeOfDay? pickupTime;
  bool isHalal = true;

  bool loading = true;
  bool saving = false;

  late String donationId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    donationId = ModalRoute.of(context)!.settings.arguments as String;
    _loadDonation();
  }

  /// LOAD DONATION
  Future<void> _loadDonation() async {
    final snap = await FirebaseFirestore.instance
        .collection("donations")
        .doc(donationId)
        .get();

    if (!snap.exists) {
      Navigator.pop(context);
      return;
    }

    final data = snap.data()!;
    final status = data["status"];

    /// 🔒 ONLY EDIT IF AVAILABLE
    if (status != "available") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This donation can no longer be edited.")),
      );
      Navigator.pop(context);
      return;
    }

    titleController.text = data["title"] ?? "";
    descController.text = data["description"] ?? "";
    qtyController.text = data["quantity"].toString();
    isHalal = data["halal"] == true;

    final pickupTimestamp = (data["pickupTimestamp"] as Timestamp).toDate();

    pickupTime = TimeOfDay(
      hour: pickupTimestamp.hour,
      minute: pickupTimestamp.minute,
    );

    setState(() => loading = false);
  }

  /// PICK PICKUP / EXPIRY TIME
  Future<void> _pickPickupTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: pickupTime ?? TimeOfDay.now(),
    );

    if (time != null) {
      setState(() => pickupTime = time);
    }
  }

  /// SAVE CHANGES
  Future<void> _saveDonation() async {
    if (titleController.text.isEmpty ||
        qtyController.text.isEmpty ||
        pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    final qty = int.tryParse(qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Quantity must be valid")));
      return;
    }

    final now = DateTime.now();

    final pickupDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      pickupTime!.hour,
      pickupTime!.minute,
    );

    /// SAFETY CHECK
    if (pickupDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pickup time must be in the future.")),
      );
      return;
    }

    setState(() => saving = true);

    await FirebaseFirestore.instance
        .collection("donations")
        .doc(donationId)
        .update({
          "title": titleController.text.trim(),
          "description": descController.text.trim(),
          "quantity": qty,
          "halal": isHalal,

          // SINGLE SOURCE OF TRUTH
          "pickupTimestamp": pickupDateTime,
          "expiryAt": pickupDateTime,

          "pickupTime":
              "${pickupTime!.hour.toString().padLeft(2, '0')}:${pickupTime!.minute.toString().padLeft(2, '0')}",

          "updatedAt": DateTime.now(),
        });

    setState(() => saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Donation updated successfully")),
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
        title: const Text("Edit Donation"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
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
                "NGOs must accept and collect before this time",
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
              onPressed: saving ? null : _saveDonation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd4a373),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
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
