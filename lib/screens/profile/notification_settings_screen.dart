import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final Color themeColor;
  const NotificationSettingsScreen({super.key, required this.themeColor});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool pushEnabled = true;
  bool emailEnabled = true;
  bool isLoading = true;
  String? role;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;

    try {
      // Check users collection first
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      role = 'customer';
      
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance.collection('providers').doc(user!.uid).get();
        role = 'provider';
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          pushEnabled = data['pushNotificationsEnabled'] ?? true;
          emailEnabled = data['emailNotificationsEnabled'] ?? true;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading notification settings: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (user == null || role == null) return;

    setState(() {
      if (key == 'pushNotificationsEnabled') pushEnabled = value;
      if (key == 'emailNotificationsEnabled') emailEnabled = value;
    });

    try {
      final collection = role == 'customer' ? 'users' : 'providers';
      await FirebaseFirestore.instance.collection(collection).doc(user!.uid).update({
        key: value,
      });
    } catch (e) {
      debugPrint("Error updating setting: $e");
      // Revert on error
      setState(() {
        if (key == 'pushNotificationsEnabled') pushEnabled = !value;
        if (key == 'emailNotificationsEnabled') emailEnabled = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update settings. Please try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Alert Settings"),
                  const SizedBox(height: 16),
                  _buildToggleTile(
                    icon: Icons.notifications_active_outlined,
                    title: "Push Notifications",
                    subtitle: "Get real-time updates about your bookings and messages",
                    value: pushEnabled,
                    onChanged: (val) => _updateSetting('pushNotificationsEnabled', val),
                  ),
                  const Divider(height: 32),
                  _buildToggleTile(
                    icon: Icons.mail_outline_rounded,
                    title: "Email Notifications",
                    subtitle: "Receive booking confirmations and status updates via email",
                    value: emailEnabled,
                    onChanged: (val) => _updateSetting('emailNotificationsEnabled', val),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.themeColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: widget.themeColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "You can also manage notifications in your device system settings.",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF475569), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: widget.themeColor,
        ),
      ],
    );
  }
}
