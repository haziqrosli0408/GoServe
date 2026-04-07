import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tracking_screen.dart';
import 'booking_screen.dart';
import 'rate_service_screen.dart';
import 'reschedule_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6B00), // Swapped white to Orange
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(45),
          bottomRight: Radius.circular(45),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 25), // Increased from 10
            _bookingTabs(),
            const SizedBox(height: 30), // Increased from 25
          ],
        ),
      ),
    );
  }

  Widget _bookingTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08), // Darker track on orange
          borderRadius: BorderRadius.circular(40),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double tabWidth = (constraints.maxWidth) / 3;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutQuart,
                  alignment: Alignment(
                    selectedTab == 0 ? -1.0 : (selectedTab == 1 ? 0.0 : 1.0),
                    0,
                  ),
                  child: Container(
                    width: tabWidth,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white, // Active tab now white
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _tabButton('Upcoming', 0),
                    _tabButton('Completed', 1),
                    _tabButton('Cancelled', 2),
                  ],
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final active = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.outfit(
                color: active ? const Color(0xFFFF6B00) : Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          "Please login to see bookings",
          style: GoogleFonts.outfit(color: Colors.black54),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
        }

        final allBookings = snapshot.data?.docs ?? [];
        
        final upcoming = allBookings.where((d) => ['Pending', 'Confirmed', 'In progress'].contains(d['status'])).toList();
        final completed = allBookings.where((d) => d['status'] == 'Completed').toList();
        final cancelled = allBookings.where((d) => d['status'] == 'Cancelled').toList();

        List<QueryDocumentSnapshot> displayList;
        String sectionTitle;
        Widget? badge;

        if (selectedTab == 0) {
          displayList = upcoming;
          sectionTitle = 'Upcoming Bookings';
          if (upcoming.isNotEmpty) {
            badge = _buildSectionBadge('${upcoming.length} Pending');
          }
        } else if (selectedTab == 1) {
          displayList = completed;
          sectionTitle = 'Completed Bookings';
        } else {
          displayList = cancelled;
          sectionTitle = 'Cancelled Bookings';
        }

        if (displayList.isEmpty) {
          // 🔹 MOCK DATA FOR DEMO PURPOSES (If empty)
          if (selectedTab == 1) {
             return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sectionTitle, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F212C))),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCompletedCard({
                  'serviceName': 'Premium House Cleaning',
                  'providerName': 'Sarah Wilson',
                  'date': 'Oct 15, 2023',
                  'totalPrice': 85.0,
                  'status': 'Completed'
                }, 'mock_id'),
                _buildCompletedCard({
                  'serviceName': 'Electrical Wiring Fix',
                  'providerName': 'John Electric',
                  'date': 'Sep 29, 2023',
                  'totalPrice': 120.0,
                  'status': 'Completed'
                }, 'mock_id_2'),
              ],
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sectionTitle, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No $sectionTitle found", style: GoogleFonts.outfit(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F212C),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
            const SizedBox(height: 20),
            ...displayList.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              if (selectedTab == 0) return _buildUpcomingCard(data, id);
              if (selectedTab == 1) return _buildCompletedCard(data, id);
              return _buildCancelledCard(data, id);
            }),
          ],
        );
      },
    );
  }

  Widget _buildSectionBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: const Color(0xFFFF6B00),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ================= UPCOMING CARD =================

  Widget _buildUpcomingCard(Map<String, dynamic> data, String id) {
    String title = data['serviceName'] ?? 'Professional cleaning';
    String category = (data['serviceName'] as String?)?.toUpperCase() ?? 'HOME MAINTENANCE';
    String date = data['date'] ?? 'Oct 24, 2023';
    String time = data['time'] ?? '09:00 AM';
    
    // Updated reliable illustration images for demo
    String imageUrl = 'https://images.unsplash.com/photo-1581578731548-c64695cc6954?q=80&w=800&auto=format&fit=crop';
    if (category.contains('CLEANING')) {
      imageUrl = 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?q=80&w=800&auto=format&fit=crop';
    } else if (category.contains('ELECTRICAL')) {
      imageUrl = 'https://images.unsplash.com/photo-1621905151189-08b45d6a269e?q=80&w=800&auto=format&fit=crop';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.handyman_outlined, size: 14, color: Color(0xFFFF6B00)),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5A5C61),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F212C),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time_filled, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => RescheduleSheet(
                              bookingId: id,
                              currentDate: date,
                              currentTime: time,
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Reschedule',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1F212C),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTrackButton(data, id),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackButton(Map<String, dynamic> data, String id) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              bookingData: data,
              bookingId: id,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Track',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ================= COMPLETED CARD =================

  Widget _buildCompletedCard(Map<String, dynamic> data, String id) {
    String title = data['serviceName'] ?? 'Kitchen Sink Repair';
    String provider = data['providerName'] ?? 'Alex J.';
    String date = data['date'] ?? 'Oct 18, 2023';
    String price = data['totalPrice']?.toString() ?? '45.00';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Service Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1581578731548-c64695cc6954?auto=format&fit=crop&q=80&w=200',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(width: 70, height: 70, color: Colors.grey.shade100, child: const Icon(Icons.broken_image, size: 20)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F212C)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'with $provider',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        date,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B00)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'RM $price',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RateServiceScreen(bookingData: data),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Rate Now',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1F212C),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingPage(
                            providerName: provider,
                            serviceName: title,
                            serviceImage: 'https://images.unsplash.com/photo-1581578731548-c64695cc6954?q=80&w=800&auto=format&fit=crop',
                            category: 'Service',
                            price: price,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Rebook',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= CANCELLED CARD =================

  Widget _buildCancelledCard(Map<String, dynamic> data, String id) {
    String title = data['serviceName'] ?? 'Car Detailing';
    String date = (data['date'] as String?)?.split(',').first ?? 'Oct 05';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F1F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F212C),
                  ),
                ),
                Text(
                  'Cancelled on $date',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingPage(
                    providerName: 'Professional', 
                    serviceName: title,
                    serviceImage: 'https://images.unsplash.com/photo-1581578731548-c64695cc6954?q=80&w=800&auto=format&fit=crop',
                    category: 'Service',
                    price: '45.0',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEBEBEB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Rebook',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5C61),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
