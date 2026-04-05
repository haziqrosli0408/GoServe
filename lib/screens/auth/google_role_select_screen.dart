import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleRoleSelectScreen extends StatefulWidget {
  final User user;
  const GoogleRoleSelectScreen({super.key, required this.user});

  @override
  State<GoogleRoleSelectScreen> createState() => _GoogleRoleSelectScreenState();
}

class _GoogleRoleSelectScreenState extends State<GoogleRoleSelectScreen> {
  bool isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => isLoading = true);
    try {
      final collection = role == "customer" ? "users" : "providers";
      
      await FirebaseFirestore.instance.collection(collection).doc(widget.user.uid).set({
        "uid": widget.user.uid,
        "name": widget.user.displayName ?? "",
        "email": widget.user.email ?? "",
        "phone": widget.user.phoneNumber ?? "", // Usually empty from Google for security
        "profileUrl": widget.user.photoURL ?? "",
        "role": role,
        "createdAt": DateTime.now(),
        if (role == "provider") "services": [],
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, role == "customer" ? "/customer" : "/provider");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "One Last\nStep",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "How would you like to use GoServe?",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 48),
              _roleCard(
                title: "I'm a Customer",
                subtitle: "Search and book local services",
                icon: Icons.person_search,
                color: const Color(0xFFFF6B00),
                onTap: () => _selectRole("customer"),
              ),
              const SizedBox(height: 16),
              _roleCard(
                title: "I'm a Service Provider",
                subtitle: "Offer my skills and earn money",
                icon: Icons.business_center,
                color: const Color(0xFF4F46E5),
                onTap: () => _selectRole("provider"),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
