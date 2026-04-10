import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboards/customer_home.dart';

class BookingCancelledScreen extends StatelessWidget {
  const BookingCancelledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 60,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 32),
              // Text
              Text(
                'Booking Cancelled',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F212C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your booking has been successfully cancelled. We hope to serve you again soon!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              // Back to Home
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Use a clean navigation to reset state and ensure we land on the Home tab
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerHome(initialIndex: 0)),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
