import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NGOProfile extends StatefulWidget {
  const NGOProfile({super.key});

  @override
  State<NGOProfile> createState() => _NGOProfileState();
}

class _NGOProfileState extends State<NGOProfile> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final stateC = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();
    if (doc.exists) {
      final d = doc.data()!;
      name.text = d["name"] ?? "";
      phone.text = d["phone"] ?? "";
      address.text = d["address"] ?? "";
      city.text = d["city"] ?? "";
      stateC.text = d["state"] ?? "";
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "name": name.text,
      "phone": phone.text,
      "address": address.text,
      "city": city.text,
      "state": stateC.text,
    });
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile updated")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text("NGO Profile"),
        backgroundColor: const Color(0xffd4a373),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "NGO Name"),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: "Address"),
            ),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: "City"),
            ),
            TextField(
              controller: stateC,
              decoration: const InputDecoration(labelText: "State"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd4a373),
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
