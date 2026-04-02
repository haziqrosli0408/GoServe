import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    try {
      // 1. Firebase Auth Login
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      // 🔹 2. AUTOMATIC ADMIN REDIRECT
      // If the email matches your admin email, go straight to Admin Dashboard
      if (email == "admin@goserve.com") {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/admin");
        return;
      }

      // 🔹 3. CHECK CUSTOMER COLLECTION (users)
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();

      if (userDoc.exists) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/customer");
        return;
      }

      // 🔹 4. CHECK PROVIDER COLLECTION
      DocumentSnapshot providerDoc =
          await FirebaseFirestore.instance
              .collection("providers")
              .doc(uid)
              .get();

      if (providerDoc.exists) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/provider");
      } else {
        throw Exception("Account not registered in database");
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed";
      if (e.code == "user-not-found") msg = "User not registered";
      if (e.code == "wrong-password") msg = "Wrong password!";
      if (e.code == "invalid-email") msg = "Invalid email format";

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome\nBack",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Login to continue using GoServe",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don’t have an account? ", style: TextStyle(color: Colors.black54, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Email address", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return "Email is required";
            if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$").hasMatch(v)) return "Invalid email";
            return null;
          },
          decoration: InputDecoration(
            hintText: "name@example.com",
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.black54, size: 20),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Password", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: passwordController,
          obscureText: hidePassword,
          validator: (v) => (v == null || v.isEmpty) ? "Password is required" : null,
          decoration: InputDecoration(
            hintText: "••••••••••••",
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54, size: 20),
            suffixIcon: IconButton(
              icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility, color: Colors.black54, size: 20),
              onPressed: () => setState(() => hidePassword = !hidePassword),
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
