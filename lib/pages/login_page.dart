import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool showPassword = false;
  String error = "";

  /// 🔑 FORGOT PASSWORD
  Future<void> _forgotPassword() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = "Please enter your email to reset password");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email")),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() => error = "Email not registered");
      } else {
        setState(() => error = "Failed to send reset email");
      }
    }
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = "Please enter your email");
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.text.trim())) {
      setState(() => error = "Please enter a valid email address");
      return;
    }

    if (password.text.isEmpty) {
      setState(() => error = "Please enter your password");
      return;
    }

    try {
      setState(() {
        loading = true;
        error = "";
      });

      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() => error = "User record not found");
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>;

      if (data["approved"] == false) {
        await FirebaseAuth.instance.signOut();
        setState(() => error = "Your account is pending admin approval");
        return;
      }

      await FCMService.initFCM();

      if (!mounted) return;

      switch (data["role"]) {
        case "restaurant":
          Navigator.pushReplacementNamed(context, "/restaurant-dashboard");
          break;
        case "ngo":
          Navigator.pushReplacementNamed(context, "/ngo-dashboard");
          break;
        case "admin":
          Navigator.pushReplacementNamed(context, "/admin-dashboard");
          break;
        default:
          setState(() => error = "Invalid user role");
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == "user-not-found") {
        setState(() => error = "Email not registered");
      } else if (e.code == "wrong-password") {
        setState(() => error = "Incorrect password");
      } else {
        setState(() => error = "Login failed. Please try again.");
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
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xffd4a373),
                  child: const Icon(
                    Icons.fastfood,
                    size: 40,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  "Food4Need",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffd4a373),
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  "Login to continue",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),

                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                TextField(
                  controller: email,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: password,
                  enabled: !loading,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                    ),
                  ),
                ),

                /// 🔑 FORGOT PASSWORD BUTTON
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : _forgotPassword,
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: Color(0xff5a3825)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffd4a373),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Login",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, "/register"),
                  child: const Text(
                    "Don't have an account? Register",
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
}
