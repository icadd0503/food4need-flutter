import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  String error = "";
  bool loading = false;

  login() async {
    if (email.text.isEmpty) {
      return setState(() => error = "Please enter your email");
    }
    if (password.text.isEmpty) {
      return setState(() => error = "Please enter your password");
    }

    try {
      setState(() => loading = true);

      // Sign in Firebase Auth
      UserCredential userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.text,
            password: password.text,
          );

      // Fetch Firestore document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      var data = userDoc.data() as Map<String, dynamic>;

      // Check approval
      if (data["approved"] == false) {
        return setState(() => error = "Your account is pending admin approval");
      }

      // Redirect based on role
      if (data["role"] == "restaurant") {
        Navigator.pushReplacementNamed(context, "/restaurant-dashboard");
      } else if (data["role"] == "ngo") {
        Navigator.pushReplacementNamed(context, "/ngo-dashboard");
      } else if (data["role"] == "admin") {
        Navigator.pushReplacementNamed(context, "/admin-dashboard");
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        setState(() => error = "Email not registered");
      } else if (e.code == "wrong-password") {
        setState(() => error = "Incorrect password");
      } else {
        setState(() => error = "Login failed. Try again.");
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
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Food4Need Login",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffd4a373),
                ),
              ),

              const SizedBox(height: 10),

              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),

              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffd4a373),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Login",
                        style: TextStyle(color: Colors.white),
                      ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () => Navigator.pushNamed(context, "/register"),
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
