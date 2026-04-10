import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  final Color themeColor;
  const NotificationsScreen({super.key, this.themeColor = const Color(0xFFFF6B00)});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              "No notifications yet",
              style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Stay tuned! We'll notify you here when something happens.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
