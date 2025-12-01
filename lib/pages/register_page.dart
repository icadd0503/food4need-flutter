import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  String role = "";
  String message = "";
  bool loading = false;

  registerUser() async {
    if (name.text.isEmpty) return setState(() => message = "Enter your name");
    if (email.text.isEmpty) return setState(() => message = "Enter your email");
    if (password.text.isEmpty)
      return setState(() => message = "Enter your password");
    if (role.isEmpty) return setState(() => message = "Select a role");

    try {
      setState(() => loading = true);

      // CREATE ACCOUNT
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );

      // SAVE USER IN DATABASE
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({
            "name": name.text.trim(),
            "email": email.text.trim(),
            "role": role,
            "approved": false, // admin must approve
            "phone": "",
            "address": "",
            "city": "",
            "state": "",
            "closingTime": "",
            "createdAt": DateTime.now(),
          });

      setState(
        () => message = "Registration successful! Await admin approval.",
      );

      // redirect to login after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, "/login");
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == "email-already-in-use") {
        setState(() => message = "Email already registered");
      } else {
        setState(() => message = "Registration failed");
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffefae0),
      body: Center(
        child: Container(
          width: 330,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Food4Need Registration",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffd4a373),
                ),
              ),

              const SizedBox(height: 10),

              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: message.contains("successful")
                        ? Colors.green
                        : Colors.red,
                  ),
                ),

              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),

              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: role.isEmpty ? null : role,
                items: const [
                  DropdownMenuItem(
                    value: "restaurant",
                    child: Text("Restaurant"),
                  ),
                  DropdownMenuItem(value: "ngo", child: Text("NGO")),
                ],
                onChanged: (value) => setState(() => role = value!),
                decoration: const InputDecoration(labelText: "Role"),
              ),

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
                onTap: () => Navigator.pushReplacementNamed(context, "/login"),
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
