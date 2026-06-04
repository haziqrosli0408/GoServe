import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tracking_screen.dart';
import 'rate_service_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/service_details.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/single_chat_screen.dart';
import 'help_center_screen.dart';
import 'reschedule_sheet.dart';
import 'cancel_booking_sheet.dart';

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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            "My Bookings",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _bookingTabs(),
          ),
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

  Widget _bookingTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light grey track
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double tabWidth = (constraints.maxWidth) / 3;
          return Stack(
            children: [
              Align(
                alignment: Alignment(
                  selectedTab == 0 ? -1.0 : (selectedTab == 1 ? 0.0 : 1.0),
                  0,
                ),
                child: Container(
                  width: tabWidth,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
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
        },
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
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color:
                    active ? const Color(0xFFFF6B00) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
      stream:
          FirebaseFirestore.instance
              .collection('bookings')
              .where('customerId', isEqualTo: user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
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

        final upcoming =
            allBookings
                .where((d) => !['Completed', 'Cancelled'].contains(d['status']))
                .toList();
        final completed =
            allBookings.where((d) => d['status'] == 'Completed').toList();
        final cancelled =
            allBookings.where((d) {
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
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No $sectionTitle found",
                        style: GoogleFonts.outfit(color: Colors.grey.shade500),
                      ),
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
    String? orderId = data['orderId'];
    String date = data['date'] ?? 'No date';
    String time = data['time'] ?? 'No time';
    String? imageUrl = data['serviceImage'];
    String status = data['status'] ?? 'Pending';
    String? providerProfileUrl = data['providerProfileUrl'];

    // Status Mapping
    bool activeWork = [
      'In progress',
      'On the way',
      'Arrived',
      'Awaiting Confirmation',
    ].contains(status);

    bool showTrackButton = activeWork || status == 'Confirmed';
    bool isAwaiting = status == 'Awaiting Confirmation';
    String displayStatus =
        status == 'Pending'
            ? 'Pending'
            : (isAwaiting
                ? 'Pending Approval'
                : (activeWork ? 'In Progress' : 'Confirmed'));
    Color statusColor =
        status == 'Pending'
            ? Colors.orange
            : (isAwaiting
                ? const Color(0xFF4F46E5)
                : (activeWork ? Colors.amber : Colors.green));

    double progressValue = 0.0;
    if (status == 'On the way') {
      progressValue = 0.25;
    } else if (status == 'Arrived') {
      progressValue = 0.5;
    } else if (status == 'In progress') {
      progressValue = 0.75;
    } else if (status == 'Awaiting Confirmation') {
      progressValue = 0.9;
    } else if (status == 'Confirmed') {
      progressValue = 0.1;
    }

    bool isInProgress = activeWork;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Service Image (Compact)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                            imageUrl,
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    _buildPlaceholderImage(60, 60),
                          )
                          : _buildPlaceholderImage(60, 60),
                ),
                const SizedBox(width: 12),
                // 🔹 Title and ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F212C),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order ID: ${orderId ?? 'GS-00000'}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Date and Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (isInProgress) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        status == 'In progress' ? 'In Progress' : status,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF6B00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOutCubic,
                      tween: Tween<double>(begin: 0, end: progressValue),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: const Color(
                            0xFFFF6B00,
                          ).withValues(alpha: 0.1),
                          color: const Color(0xFFFF6B00),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 🔹 Provider & Status Row (Above Buttons)
                if (!isInProgress) ...[
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('providers').doc(data['providerId']).get(),
                    builder: (context, snapshot) {
                      String? liveProfileUrl;
                      double rating = 0.0;
                      int reviews = 0;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final pData = snapshot.data!.data() as Map<String, dynamic>;
                        liveProfileUrl = pData['profileUrl'] ?? pData['photoUrl'] ?? pData['profileImageUrl'];
                        rating = (pData['rating'] ?? 0.0).toDouble();
                        reviews = (pData['reviews'] ?? 0).toInt();
                      }

                      return Row(
                        children: [
                          // Provider Avatar (Aligned with Service Image)
                          SizedBox(
                            width: 60,
                            child: Center(
                              child: _buildAvatar(liveProfileUrl ?? providerProfileUrl, providerName),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Provider Name and Rating
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  providerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '($reviews reviews)',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Status Badge (Right, Parallel with Rating)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        displayStatus,
                                        style: GoogleFonts.outfit(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Buttons (Shorter)
                Row(
                  children: [
                    // Chat Button (Always visible)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SingleChatScreen(
                                    provider: {
                                      'providerId': data['providerId'],
                                      'providerName': data['providerName'] ?? 'Provider',
                                      'providerProfileUrl': data['providerProfileUrl'],
                                      'serviceName': serviceName,
                                      'title': serviceName,
                                    },
                                  ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        label: Text(
                          "Chat",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF1F212C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!showTrackButton)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showBookingDetails(data, id);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                          child: Text(
                            "View Details",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF1F212C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (showTrackButton)
                      Expanded(child: _buildTrackButton(data, id)),
                  ],
                ),
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
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: (width != null && width < 100) ? 24 : 40,
        ),
      ),
    );
  }

  Widget _buildTrackButton(Map<String, dynamic> data, String id) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              bookingData: Map<String, dynamic>.from(data)..['id'] = id,
              bookingId: id,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(double.infinity, 40),
      ),
      child: Text(
        'Tracking',
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ================= COMPLETED CARD =================

  Widget _buildCompletedCard(Map<String, dynamic> data, String id) {
    String serviceName = data['serviceName'] ?? 'Service';
    String providerName = data['providerName'] ?? 'Provider';
    String? orderId = data['orderId'];
    String date = data['date'] ?? 'No date';
    String time = data['time'] ?? 'No time';
    String? imageUrl = data['serviceImage'];
    String? providerProfileUrl = data['providerProfileUrl'];
    String price = data['totalPrice']?.toString() ?? '0.00';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Service Image (Compact)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderImage(60, 60),
                        )
                      : _buildPlaceholderImage(60, 60),
                ),
                const SizedBox(width: 12),
                // 🔹 Title and ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F212C),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order ID: ${orderId ?? 'GS-00000'}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Date and Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 10,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('providers')
                      .doc(data['providerId'])
                      .get(),
                  builder: (context, snapshot) {
                    String? liveProfileUrl;
                    double rating = 0.0;
                    int reviews = 0;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final pData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      liveProfileUrl = pData['profileUrl'] ??
                          pData['photoUrl'] ??
                          pData['profileImageUrl'];
                      rating = (pData['rating'] ?? 0.0).toDouble();
                      reviews = (pData['reviews'] ?? 0).toInt();
                    }

                    return Row(
                      children: [
                        // Provider Avatar
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: _buildAvatar(
                                liveProfileUrl ?? providerProfileUrl,
                                providerName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Provider Name and Rating
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerName,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($reviews reviews)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'RM $price',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (data['isRated'] != true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RateServiceScreen(
                            bookingData: Map<String, dynamic>.from(data)
                              ..['id'] = id,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceDetailsScreen(provider: data),
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 40,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: data['isRated'] != true
                          ? const Color(0xFFFF6B00)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: data['isRated'] == true
                          ? Border.all(color: const Color(0xFFFF6B00), width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        data['isRated'] != true ? 'Rate Now' : 'Book Again',
                        style: GoogleFonts.outfit(
                          color: data['isRated'] != true ? Colors.white : const Color(0xFFFF6B00),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            child:
                imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => _buildPlaceholderImage(60, 60),
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
                  builder: (context) => ServiceDetailsScreen(provider: data),
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

  void _showBookingDetails(Map<String, dynamic> data, String bookingId) async {
    final String serviceName = data['serviceName'] ?? 'Service';
    final String providerName = data['providerName'] ?? 'Elite Pro';
    final String orderId = data['orderId'] ?? 'GS-00000';
    final String date = data['date'] ?? 'No date';
    final String time = data['time'] ?? 'No time';
    final String address = data['address'] ?? 'No address provided';
    final String? serviceImage = data['serviceImage'];
    final String providerId = data['providerId'] ?? '';

    // Fetch latest provider profile info
    String? providerProfileUrl;
    String? providerPhone;

    if (providerId.isNotEmpty) {
      // 1. Try 'users' collection
      var providerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(providerId)
              .get();

      // 2. Try 'providers' collection if not in users
      if (!providerDoc.exists) {
        providerDoc =
            await FirebaseFirestore.instance
                .collection('providers')
                .doc(providerId)
                .get();
      }

      if (providerDoc.exists) {
        final pData = providerDoc.data() as Map<String, dynamic>;
        providerProfileUrl = pData['profileUrl'];
        providerPhone = pData['phone'];
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Order ID: $orderId',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF6B00),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Service and Provider Header
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child:
                                  serviceImage != null &&
                                          serviceImage.isNotEmpty
                                      ? Image.network(
                                        serviceImage,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      )
                                      : _buildPlaceholderImage(80, 80),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    serviceName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Provider Info
                        _buildDetailSection('SERVICE PROVIDER', [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(
                                  0xFFFF6B00,
                                ).withValues(alpha: 0.1),
                                backgroundImage:
                                    (providerProfileUrl != null &&
                                            providerProfileUrl.isNotEmpty)
                                        ? NetworkImage(providerProfileUrl)
                                        : null,
                                child:
                                    (providerProfileUrl == null ||
                                            providerProfileUrl.isEmpty)
                                        ? Text(
                                          providerName.isNotEmpty
                                              ? providerName[0].toUpperCase()
                                              : 'P',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFFF6B00),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  providerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  _contactAction(
                                    Icons.chat_bubble_outline_rounded,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => SingleChatScreen(
                                                provider: {
                                                  'providerId': providerId,
                                                  'providerName': providerName,
                                                  'providerProfileUrl':
                                                      providerProfileUrl,
                                                  'serviceName': serviceName,
                                                  'serviceId':
                                                      data['serviceId'],
                                                },
                                                themeColor: const Color(
                                                  0xFFFF6B00,
                                                ),
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _contactAction(
                                    Icons.phone_outlined,
                                    () async {
                                      if (providerPhone != null &&
                                          providerPhone.isNotEmpty) {
                                        final Uri telUri = Uri(
                                          scheme: 'tel',
                                          path: providerPhone,
                                        );
                                        if (await canLaunchUrl(telUri)) {
                                          await launchUrl(telUri);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Booking Info
                        _buildDetailSection('BOOKING INFO', [
                          _detailRow(
                            Icons.calendar_today_outlined,
                            'Date',
                            date,
                          ),
                          _detailRow(Icons.access_time_outlined, 'Time', time),
                          _detailRow(
                            Icons.location_on_outlined,
                            'Address',
                            address,
                            isExpandable: true,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Payment Summary
                        _buildDetailSection('PAYMENT SUMMARY', [
                          _priceRow('Base Price', data['basePrice'] ?? 0),
                          if (data['selectedAddOns'] != null &&
                              (data['selectedAddOns'] as List).isNotEmpty)
                            ...(data['selectedAddOns'] as List).map(
                              (addon) => _priceRow(
                                addon['name'] ?? 'Add-on',
                                addon['price'] ?? 0,
                                isAddon: true,
                              ),
                            ),
                          _priceRow(
                            'Platform Fee (15%)',
                            data['chargeFee'] ?? 0,
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Paid',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'RM ${(data['totalPrice'] ?? 0).toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF6B00),
                                ),
                              ),
                            ],
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            // FAQ Button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => HelpCenterScreen(
                                            bookingData: data,
                                          ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  foregroundColor: const Color(0xFF64748B),
                                  textStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('FAQ'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Reschedule Button
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder:
                                        (context) => RescheduleSheet(
                                          bookingId: bookingId,
                                          currentDate: date,
                                          currentTime: time,
                                        ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6B00),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                  textStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Reschedule'),
                              ),
                            ),
                          ],
                        ),
                        
                        // Cancel Booking Button (if eligible)
                        if (['Pending', 'Confirmed', 'Awaiting Confirmation'].contains(data['status'])) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => CancelBookingSheet(
                                    bookingId: bookingId,
                                    bookingData: data,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.red.shade200),
                                foregroundColor: Colors.red.shade500,
                                textStyle: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancel Booking'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[400],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool isExpandable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            isExpandable ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: isExpandable ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, dynamic price, {bool isAddon = false}) {
    final double value =
        (price is num)
            ? price.toDouble()
            : (double.tryParse(price.toString()) ?? 0.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isAddon ? " + $label" : label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isAddon ? Colors.grey[500] : const Color(0xFF1E293B),
              fontWeight: isAddon ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFFF6B00), size: 18),
      ),
    );
  }
  Widget _buildAvatar(String? profileUrl, String name) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade100,
      backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
          ? NetworkImage(profileUrl)
          : null,
      child: (profileUrl == null || profileUrl.isEmpty)
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'P',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            )
          : null,
    );
  }
}
