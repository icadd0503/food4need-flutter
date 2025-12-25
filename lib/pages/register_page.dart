import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // COMMON
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  // RESTAURANT
  final businessRegNo = TextEditingController();
  TimeOfDay? openTime;
  TimeOfDay? closeTime;
  bool halal = true;

  // NGO
  final ngoRegNo = TextEditingController();
  final coverageArea = TextEditingController();
  final contactPerson = TextEditingController();

  String role = "";
  String message = "";
  bool loading = false;

  // ================= TIME PICKER =================
  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

  // ================= REGISTER =================
  Future<void> registerUser() async {
    if (loading) return;

    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty ||
        phone.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      setState(() => message = "Please fill all required fields");
      return;
    }

    if (!email.text.contains("@")) {
      setState(() => message = "Please enter a valid email");
      return;
    }

    if (password.text.length < 6) {
      setState(() => message = "Password must be at least 6 characters");
      return;
    }

    if (role.isEmpty) {
      setState(() => message = "Please select a role");
      return;
    }

    if (role == "restaurant" &&
        (businessRegNo.text.trim().isEmpty ||
            openTime == null ||
            closeTime == null)) {
      setState(() => message = "Please complete restaurant information");
      return;
    }

    if (role == "ngo" &&
        (ngoRegNo.text.trim().isEmpty ||
            coverageArea.text.trim().isEmpty ||
            contactPerson.text.trim().isEmpty)) {
      setState(() => message = "Please complete NGO information");
      return;
    }

    try {
      setState(() {
        loading = true;
        message = "";
      });

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(cred.user!.uid)
          .set({
            "name": name.text.trim(),
            "email": email.text.trim(),
            "phone": phone.text.trim(),
            "address": address.text.trim(),
            "role": role,

            // RESTAURANT
            "businessRegNo": role == "restaurant"
                ? businessRegNo.text.trim()
                : null,
            "operatingHours": role == "restaurant"
                ? "${openTime!.format(context)} - ${closeTime!.format(context)}"
                : null,
            "halal": role == "restaurant" ? halal : null,

            // NGO
            "ngoRegNo": role == "ngo" ? ngoRegNo.text.trim() : null,
            "coverageArea": role == "ngo" ? coverageArea.text.trim() : null,
            "contactPerson": role == "ngo" ? contactPerson.text.trim() : null,

            "approved": false,
            "createdAt": DateTime.now(),
          });

      if (!mounted) return;

      setState(() {
        message = "Registration successful! Await admin approval.";
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/login");
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = "Registration failed");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameLabel = role == "restaurant"
        ? "Restaurant Name"
        : role == "ngo"
        ? "NGO Name"
        : "Name";

    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Food4Need Registration",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffd4a373),
                  ),
                ),

                const SizedBox(height: 12),

                /// 🔥 REGISTER AS (MOVED TO TOP)
                DropdownButtonFormField<String>(
                  value: role.isEmpty ? null : role,
                  decoration: const InputDecoration(
                    labelText: "Register As",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "restaurant",
                      child: Text("Restaurant"),
                    ),
                    DropdownMenuItem(value: "ngo", child: Text("NGO")),
                  ],
                  onChanged: (v) => setState(() => role = v!),
                ),

                const SizedBox(height: 14),

                if (message.isNotEmpty)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: message.contains("successful")
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),

                const SizedBox(height: 12),

                _input(name, nameLabel),
                _input(email, "Email", keyboard: TextInputType.emailAddress),
                _input(password, "Password", obscure: true),
                _input(phone, "Phone Number", keyboard: TextInputType.phone),
                _input(address, "Address"),

                if (role == "restaurant") ...[
                  _sectionTitle("Restaurant Information"),
                  _input(businessRegNo, "Business Registration No"),

                  _sectionTitle("Operating Hours"),
                  ListTile(
                    title: Text(
                      openTime == null
                          ? "Select Opening Time"
                          : "Open: ${openTime!.format(context)}",
                    ),
                    trailing: const Icon(Icons.schedule),
                    onTap: () => _pickTime(true),
                  ),
                  ListTile(
                    title: Text(
                      closeTime == null
                          ? "Select Closing Time"
                          : "Close: ${closeTime!.format(context)}",
                    ),
                    trailing: const Icon(Icons.schedule),
                    onTap: () => _pickTime(false),
                  ),

                  SwitchListTile(
                    value: halal,
                    title: const Text("Halal Food"),
                    onChanged: (v) => setState(() => halal = v),
                  ),
                ],

                if (role == "ngo") ...[
                  _sectionTitle("NGO Information"),
                  _input(ngoRegNo, "NGO Registration No"),
                  _input(coverageArea, "Coverage Area"),
                  _input(contactPerson, "Contact Person"),
                ],

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: loading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffd4a373),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Register",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),

                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, "/login"),
                  child: const Text(
                    "Already have an account? Login",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff5a3825),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xff5a3825),
        ),
      ),
    );
  }
}
