import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tracking_screen.dart';
import 'booking_screen.dart';
import 'rate_service_screen.dart';
import 'reschedule_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/service_details.dart';

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
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              "My Bookings",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _bookingTabs(),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }

  Widget _bookingTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08), // Darker track on orange
          borderRadius: BorderRadius.circular(30),
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
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white, // Active tab now white
                      borderRadius: BorderRadius.circular(25),
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
          height: 36,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.outfit(
                color: active ? const Color(0xFFFF6B00) : Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
        
        // 🔹 SORT BY LATEST BOOKED (createdAt DESC)
        allBookings.sort((a, b) {
          final Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          final Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
          final Timestamp? tA = dataA['createdAt'] as Timestamp?;
          final Timestamp? tB = dataB['createdAt'] as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });
        
        final upcoming = allBookings.where((d) => ['Pending', 'Confirmed', 'On the way', 'Arrived', 'In progress'].contains(d['status'])).toList();
        final completed = allBookings.where((d) => d['status'] == 'Completed').toList();
        final cancelled = allBookings.where((d) {
          if (d['status'] != 'Cancelled') return false;
          final dynamic data = d.data();
          if (data is! Map<String, dynamic>) return true;
          
          final Timestamp? cancelledAt = data['cancelledAt'];
          
          final now = DateTime.now();
          
          if (cancelledAt != null) {
            return now.difference(cancelledAt.toDate()).inDays < 3;
          }
          // Legacy check: returning false effectively hides/deletes all existing cancelled bookings
          // so only new ones with the 'cancelledAt' timestamp will show up.
          return false;
        }).toList();

        List<QueryDocumentSnapshot> displayList;
        String sectionTitle;

        if (selectedTab == 0) {
          displayList = upcoming;
          sectionTitle = 'Upcoming Bookings';
        } else if (selectedTab == 1) {
          displayList = completed;
          sectionTitle = 'Completed Bookings';
        } else {
          displayList = cancelled;
          sectionTitle = 'Cancelled Bookings';
        }

        if (displayList.isEmpty) {

          
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

  // ================= UPCOMING CARD =================

  Widget _buildUpcomingCard(Map<String, dynamic> data, String id) {
    String serviceName = data['serviceName'] ?? 'Service';
    String providerName = data['providerName'] ?? 'Elite Pro';
    String category = (data['category'] as String?)?.toUpperCase() ?? 'SERVICE';
    
    String date = data['date'] ?? 'No date';
    String time = data['time'] ?? 'No time';
    String? imageUrl = data['serviceImage'];

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
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
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
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  serviceName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F212C),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'by ',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      providerName,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time_filled, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
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
                                fontWeight: FontWeight.w600,
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

  Widget _buildPlaceholderImage([double? width, double? height]) {
    return Container(
      height: height ?? 140,
      width: width ?? double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: (width != null && width < 100) ? 24 : 40),
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
              fontWeight: FontWeight.w600,
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
                        child: data['serviceImage'] != null && data['serviceImage'].isNotEmpty
                            ? Image.network(
                                data['serviceImage'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(70, 70),
                              )
                            : _buildPlaceholderImage(70, 70),
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
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'with $provider',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        date,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B00)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'RM $price',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
            GestureDetector(
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
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Rate Now',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CANCELLED CARD =================

  Widget _buildCancelledCard(Map<String, dynamic> data, String id) {
    String title = data['serviceName'] ?? 'Service';
    String date = data['date'] ?? 'No date';
    String? imageUrl = data['serviceImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Service Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(60, 60),
                  )
                : _buildPlaceholderImage(60, 60),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F212C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cancelled on $date',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Rebook Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceDetailsScreen(
                    provider: data,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Rebook',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
