import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/single_chat_screen.dart';
import 'booking_cancelled_screen.dart';
import 'help_center_screen.dart';

class TrackingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;
  const TrackingScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  void _showCancelConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                'Cancel Booking?',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1F212C)),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to cancel this booking? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade500, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Keep Booking', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // 🔹 UPDATE STATUS IN FIRESTORE
                        try {
                          await FirebaseFirestore.instance
                              .collection('bookings')
                              .doc(widget.bookingId)
                              .update({'status': 'Cancelled'});
                        } catch (e) {
                          debugPrint('Error cancelling booking: $e');
                        }

                        if (!context.mounted) return;
                        Navigator.pop(context); // Close bottom sheet
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const BookingCancelledScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text('Confirm Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Map Placeholder - Now filling the top
              Expanded(
                flex: 4,
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/map_mock.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Content Area
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 110, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildServiceStatus(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
              ),
            ),
          ),
          
          // Floating Stats Card (Arrival/Distance)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.31,
            left: 20,
            right: 20,
            child: _buildFloatingStats(),
          ),

          // Provider Info Card
          Positioned(
            top: MediaQuery.of(context).size.height * 0.38,
            left: 20,
            right: 20,
            child: _buildProviderCard(),
          ),

          // Bottom Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(Icons.access_time_filled, 'ESTIMATED ARRIVAL', '15 mins'),
            VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
            _statItem(null, 'DISTANCE', '2.4 miles'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData? icon, String label, String value) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF0E6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF6B00)),
          ),
          const SizedBox(width: 10),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 0.5),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1F212C)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderCard() {
    String name = widget.bookingData['providerName'] ?? 'Ali\'s Expert Cleaning';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$name'),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80), // Vibrant Green
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E212C),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(128 reviews)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SingleChatScreen(
                    provider: {
                      'name': name,
                      'profileUrl': 'https://i.pravatar.cc/150?u=$name',
                    },
                  ),
                ),
              );
            },
            child: _actionIcon(Icons.chat_bubble_rounded),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF1E212C), size: 20),
    );
  }

  Widget _buildServiceStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Status',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 24),
          _statusTimelineItem(
            'Booking Confirmed', 
            'Your pro is confirmed for 2:00 PM', 
            '1:15 PM', 
            isCompleted: true, 
            isLast: false,
          ),
          _statusTimelineItem(
            'Professional on the way', 
            'Ali is driving to your location', 
            'Happening now', 
            isActive: true, 
            isLast: false,
          ),
          _statusTimelineItem(
            'Arrived', 
            'Estimated arrival at 2:05 PM', 
            '', 
            isLast: false,
          ),
          _statusTimelineItem(
            'Work in progress', 
            'The magic is happening!', 
            '', 
            isLast: false,
          ),
          _statusTimelineItem(
            'Completed', 
            'Service will be marked done here', 
            '', 
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _statusTimelineItem(String title, String subtitle, String time, {bool isCompleted = false, bool isActive = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFFF6B00) : (isActive ? Colors.white : Colors.grey.shade200),
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: const Color(0xFFFF6B00), width: 6) : null,
                ),
                child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFFFF6B00) : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15, 
                      fontWeight: FontWeight.bold, 
                      color: isActive ? const Color(0xFFFF6B00) : (isCompleted ? const Color(0xFF1F212C) : Colors.grey.shade400)
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(fontSize: 13, color: isCompleted || isActive ? Colors.grey.shade600 : Colors.grey.shade300),
                    ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: isActive ? Colors.deepOrange.shade800 : Colors.grey.shade400
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _showCancelConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Cancel\nBooking', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, height: 1.1)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HelpCenterScreen(bookingData: widget.bookingData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Help Center', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
