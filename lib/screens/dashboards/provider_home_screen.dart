import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/profile_screen.dart';

import 'package:url_launcher/url_launcher.dart';
import '../chat/single_chat_screen.dart';

import 'package:intl/intl.dart';
import '../misc/notifications_screen.dart';
import 'provider_service_requests_page.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? providerData;
  // Real Stats
  double totalEarnings = 0.0;
  int totalBookings = 0;
  double averageRating = 0.0;

  // Calendar State
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  final ScrollController _calendarScrollController = ScrollController(initialScrollOffset: 11 * 63.0);

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _fetchProviderData();
    _fetchProviderStats();
    _fetchCalendarEvents();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCalendarEvents() async {
    if (user == null) return;
    
    // Listen to confirmed bookings for the calendar
    FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: user!.uid)
        .where('status', whereIn: ['Confirmed', 'On the way', 'Arrived', 'In progress', 'Work in progress'])
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final Map<DateTime, List<dynamic>> newEvents = {};
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id; // Add document ID
          final dateStr = data['date'];
          if (dateStr != null) {
            DateTime? parsedDate;
            
            // Try different date formats
            final formats = [
              "d MMM yyyy",
              "yyyy-MM-dd",
              "dd/MM/yyyy",
              "MM/dd/yyyy",
            ];

            for (var format in formats) {
              try {
                parsedDate = DateFormat(format).parse(dateStr.toString().trim());
                break; // Stop if we successfully parse
              } catch (_) {}
            }

            if (parsedDate != null) {
              final dayKey = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
              if (newEvents[dayKey] == null) newEvents[dayKey] = [];
              newEvents[dayKey]!.add(data);
            } else {
              debugPrint("Could not parse date: $dateStr");
            }
          }
        }
        setState(() => _events = newEvents);
      }
    });
  }

  Future<void> _fetchProviderData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('providers')
        .doc(user!.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        providerData = doc.data();
      });
    }
  }

  Future<void> _fetchProviderStats() async {
    if (user == null) return;

    // 1. Fetch Total Bookings
    FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: user!.uid)
        .get()
        .then((snapshot) {
      if (mounted) {
        setState(() => totalBookings = snapshot.size);
      }
    });

    // 2. Calculate Total Earnings (net earnings after platform fee)
    FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'Completed')
        .get()
        .then((snapshot) {
      if (mounted) {
        double totalNetEarnings = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['payoutStatus'] == 'transferred') {
            // Get Total Price
            final totalPriceStr = data['totalPrice'] ?? data['price'] ?? '0';
            final cleanTotalPrice = double.tryParse(totalPriceStr.toString().replaceAll('RM', '').trim()) ?? 0.0;
            
            // Get Platform Fee (Charge Fee)
            // If chargeFee is stored, use it. Otherwise calculate based on 15% markup (Total = Subtotal * 1.15)
            double chargeFee = 0.0;
            if (data['chargeFee'] != null) {
              chargeFee = (data['chargeFee'] as num).toDouble();
            } else {
              // Fallback: Charge Fee = Total Price - (Total Price / 1.15)
              chargeFee = cleanTotalPrice - (cleanTotalPrice / 1.15);
            }
            
            totalNetEarnings += (cleanTotalPrice - chargeFee);
          }
        }
        setState(() => totalEarnings = totalNetEarnings);
      }
    });

    // 3. Calculate Average Rating
    FirebaseFirestore.instance
        .collection('reviews')
        .where('providerId', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'Approved')
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        double totalRating = 0;
        for (var doc in snapshot.docs) {
          totalRating += (doc.data()['rating'] as num).toDouble();
        }
        setState(() => averageRating = totalRating / snapshot.docs.length);
      }
    });
  }


  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Header Background
              Container(
                width: double.infinity,
                height: 240,
                color: const Color(0xFF4F46E5),
              ),
              Column(
                children: [
                  // Header Info Skeleton
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 60),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 100, height: 14, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 8),
                              SkeletonBox(width: 150, height: 26, color: Colors.white.withValues(alpha: 0.2)),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body Sheet Skeleton
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          // Calendar Skeleton
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SkeletonBox(
                              width: double.infinity,
                              height: 350,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Requests Title Skeleton
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: SkeletonBox(width: 180, height: 20),
                          ),
                          const SizedBox(height: 16),
                          // Requests Box Skeleton
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SkeletonBox(
                              width: double.infinity,
                              height: 120,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: providerData == null
          ? _buildSkeletonLoader()
          : SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      // 1. Purple Background Header
                      Container(
                        width: double.infinity,
                        height: 280, // Fixed height for the purple part
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      // 2. Content
                      Column(
                        children: [
                          _buildHeader(),
                          Transform.translate(
                            offset: const Offset(0, -40),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 32),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: _buildCalendarSection(),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: _buildTimelineSection(),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildNewRequestsSection(),

                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 60),
        child: Row(
          children: [
            // Left: Profile Picture
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen(themeColor: Color(0xFF4F46E5))),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (providerData?['profileUrl'] != null && providerData!['profileUrl'].toString().isNotEmpty)
                      ? NetworkImage(providerData!['profileUrl'])
                      : null,
                  child: (providerData?['profileUrl'] == null || providerData!['profileUrl'].toString().isEmpty)
                      ? Text(
                          (providerData?['name'] ?? 'P')[0].toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Middle: Welcome Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${providerData?['name'] ?? 'Provider'}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Welcome to GoServe',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Right: Notification Icon
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('providerId', isEqualTo: user?.uid)
                      .where('status', isEqualTo: 'Pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasNew = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        if (hasNew)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildCalendarSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 CUSTOM CALENDAR HEADER
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay != null ? DateFormat.yMMMM().format(_selectedDay!) : DateFormat.yMMMM().format(DateTime.now()),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = DateTime.now();
                    });
                    _calendarScrollController.animateTo(
                      11 * 63.0, 
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Today",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Horizontal Date Selector
          SizedBox(
            height: 90,
            child: ListView.builder(
              controller: _calendarScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 90, // Start 14 days ago, show 90 days total
              itemBuilder: (context, index) {
                DateTime day = DateTime.now().add(Duration(days: index - 14));
                day = DateTime(day.year, day.month, day.day); // Normalize
                DateTime selDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                
                bool isSelected = day.isAtSameMomentAs(selDay);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: Container(
                    width: 55,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('E').format(day).substring(0, 2),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[500],
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    if (_selectedDay == null) return const SizedBox();
    
    final dayKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final events = _events[dayKey] ?? [];

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No activities scheduled',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Column(
        children: events.map((event) {
          final timeStr = event['time'] ?? '00:00';
          String displayTime = timeStr.toString().replaceAll(RegExp(r'[apAP][mM]|\s'), '').replaceAll(':', '.');
          final String customerId = event['customerId'] ?? '';
          
          return FutureBuilder<DocumentSnapshot>(
            future: customerId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(customerId).get() : null,
            builder: (context, snapshot) {
              String customerName = event['customerName'] ?? 'Customer';
              if (snapshot.hasData && snapshot.data?.exists == true) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null && userData['name'] != null) {
                  customerName = userData['name'];
                }
              }

              // Determine Order ID
              String displayOrderId = event['orderId'] ?? '';
              if (displayOrderId.isEmpty) {
                String docId = event['id']?.toString() ?? 'N/A';
                displayOrderId = docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    SizedBox(
                      width: 50,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14.0),
                        child: Text(
                          displayTime,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.blueGrey[300],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5), // Indigo
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['serviceName'] ?? 'Booking',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order ID: $displayOrderId',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.white24,
                                  child: Text(
                                    customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    customerName,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }




  Widget _buildSectionHeader(String title, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: onTap,
              child: Text(
                action,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('New Service Requests', docs.isNotEmpty ? 'See all' : '', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProviderServiceRequestsPage()),
              );
            }),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, color: Colors.grey[300], size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'No new requests',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: docs.length > 3 ? 3 : docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                final String customerId = data['customerId'] ?? '';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
                  builder: (context, userSnapshot) {
                    String customerName = 'Customer';
                    String? profileUrl;
                    String? customerPhone;
                    
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      customerName = userData['name'] ?? 'Customer';
                      profileUrl = userData['profileUrl'];
                      customerPhone = userData['phone'];
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
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
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFF1F5F9),
                                backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                                child: profileUrl == null ? const Icon(Icons.person, color: Color(0xFF94A3B8), size: 24) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 17),
                                    ),
                                    Text(
                                      data['serviceName'] ?? 'Service',
                                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Order ID: ${data['orderId'] ?? 'GS-00000'}',
                                      style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final double basePrice = (data['basePrice'] is num) ? (data['basePrice'] as num).toDouble() : (double.tryParse(data['basePrice'].toString()) ?? 0.0);
                                  final List addOns = data['selectedAddOns'] ?? [];
                                  double addOnsTotal = 0;
                                  for (var addon in addOns) {
                                    final price = addon['price'];
                                    addOnsTotal += (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0.0);
                                  }
                                  
                                  return Text(
                                    'RM ${(basePrice + addOnsTotal).toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, color: Colors.grey[500], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['date'] ?? 'No date',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.access_time_outlined, color: Colors.grey[500], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    data['time'] ?? 'No time',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showBookingDetails(data, customerName, profileUrl, customerPhone),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF8FAFC),
                                    foregroundColor: const Color(0xFF4F46E5),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text('Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _updateBookingStatus(doc.id, 'Confirmed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text('Accept', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }



  void _updateBookingStatus(String bookingId, String status) {
    FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }

  void _showBookingDetails(Map<String, dynamic> data, String customerName, String? profileUrl, String? customerPhone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Details',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review the order information below',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Customer Section
                    _buildDetailSection('CUSTOMER', [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[100],
                            backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                                ? NetworkImage(profileUrl)
                                : null,
                            child: (profileUrl == null || profileUrl.isEmpty)
                                ? const Icon(Icons.person, color: Color(0xFF4F46E5))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  customerPhone ?? 'Phone not provided',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Phone Action
                          IconButton(
                            onPressed: () async {
                              if (customerPhone != null && customerPhone.isNotEmpty) {
                                // Clean the phone number (remove spaces, dashes, etc.)
                                final cleanPhone = customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
                                final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
                                
                                try {
                                  await launchUrl(telUri);
                                } catch (e) {
                                  // Fallback or error logging
                                  debugPrint("Could not launch $telUri: $e");
                                }
                              }
                            },
                            icon: const Icon(Icons.phone_outlined, color: Color(0xFF4F46E5), size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Message Action
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SingleChatScreen(
                                    provider: {
                                      'providerId': data['customerId'],
                                      'providerName': customerName,
                                      'providerProfileUrl': data['customerProfileUrl'],
                                      'serviceName': data['serviceName'],
                                      'serviceId': data['serviceId'],
                                    },
                                    themeColor: const Color(0xFF4F46E5),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Service Info
                    _buildDetailSection('SERVICE INFO', [
                      _detailRow(Icons.tag, 'Order ID', data['orderId'] ?? 'GS-00000'),
                      _detailRow(Icons.cleaning_services_outlined, 'Service', data['serviceName'] ?? 'Service', isExpandable: true),
                      if (data['selectedAddOns'] != null && (data['selectedAddOns'] as List).isNotEmpty)
                        _detailRow(Icons.add_box_outlined, 'Add-ons', (data['selectedAddOns'] as List).map((a) => a['name']).join(', '), isExpandable: true),
                      _detailRow(Icons.calendar_today_outlined, 'Date', data['date'] ?? 'No date'),
                      _detailRow(Icons.access_time_outlined, 'Time', data['time'] ?? 'No time'),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Location
                    _buildDetailSection('LOCATION', [
                      _detailRow(Icons.location_on_outlined, 'Address', data['address'] ?? 'No address provided', isExpandable: true),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Payment Breakdown
                    _buildDetailSection('PAYMENT SUMMARY', [
                      _priceRow('Base Price', data['basePrice'] ?? 0),
                      if (data['selectedAddOns'] != null && (data['selectedAddOns'] as List).isNotEmpty)
                        ... (data['selectedAddOns'] as List).map((addon) => 
                          _priceRow(addon['name'] ?? 'Add-on', addon['price'] ?? 0, isAddon: true)
                        ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your Earnings', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                              Text('(Base + Add-ons)', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[400])),
                            ],
                          ),
                          Builder(
                            builder: (context) {
                              final double basePrice = (data['basePrice'] is num) ? (data['basePrice'] as num).toDouble() : (double.tryParse(data['basePrice'].toString()) ?? 0.0);
                              final List addOns = data['selectedAddOns'] ?? [];
                              double addOnsTotal = 0;
                              for (var addon in addOns) {
                                final price = addon['price'];
                                addOnsTotal += (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0.0);
                              }
                              
                              final totalEarnings = basePrice + addOnsTotal;
                              
                              return Text(
                                'RM ${totalEarnings.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4F46E5),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ]),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool isExpandable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: isExpandable ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                  maxLines: isExpandable ? 5 : 1,
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
    final double value = (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0.0);
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
              fontWeight: isAddon ? FontWeight.w400 : FontWeight.w500
            ),
          ),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 14, 
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? color;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.color,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.1 + (_animation.value - 1.0).clamp(0.0, 0.6),
                0.3 + (_animation.value - 1.0).clamp(0.0, 0.6),
                0.5 + (_animation.value - 1.0).clamp(0.0, 0.6),
              ],
              colors: widget.color != null 
                  ? [
                      widget.color!,
                      widget.color!.withValues(alpha: widget.color!.a * 0.5),
                      widget.color!,
                    ]
                  : [
                      Colors.grey[200]!,
                      Colors.grey[100]!,
                      Colors.grey[200]!,
                    ],
            ),
          ),
        );
      },
    );
  }
}
