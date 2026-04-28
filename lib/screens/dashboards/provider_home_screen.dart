import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/profile_screen.dart';

import 'package:url_launcher/url_launcher.dart';
import '../chat/single_chat_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

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
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchProviderData();
    _fetchProviderStats();
    _fetchCalendarEvents();
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


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Container(
            color: const Color(0xFF4F46E5),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
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

          // Calendar Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SkeletonBox(
              width: double.infinity,
              height: 350,
              borderRadius: BorderRadius.circular(24),
            ),
          ),

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


          // Stats Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: (MediaQuery.of(context).size.width - 64) / 3, height: 80, borderRadius: BorderRadius.circular(16)),
                SkeletonBox(width: (MediaQuery.of(context).size.width - 64) / 3, height: 80, borderRadius: BorderRadius.circular(16)),
                SkeletonBox(width: (MediaQuery.of(context).size.width - 64) / 3, height: 80, borderRadius: BorderRadius.circular(16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: providerData == null
          ? _buildSkeletonLoader()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: _buildCalendarSection(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildNewRequestsSection(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: _buildStatsRow(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF4F46E5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    providerData?['name'] ?? 'Provider',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: (providerData?['profileUrl'] != null && providerData!['profileUrl'].toString().isNotEmpty)
                      ? NetworkImage(providerData!['profileUrl'])
                      : null,
                  child: (providerData?['profileUrl'] == null || providerData!['profileUrl'].toString().isEmpty)
                      ? Text(
                          (providerData?['name'] ?? 'P')[0].toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statItem(
            'RM ${totalEarnings >= 1000 ? "${(totalEarnings / 1000).toStringAsFixed(1)}k" : totalEarnings.toStringAsFixed(0)}',
            'Earnings',
            Icons.insights,
            Colors.blue),
        _statItem(totalBookings.toString(), 'Bookings', Icons.calendar_today,
            const Color(0xFF4F46E5)),
        _statItem(averageRating == 0 ? '0.0' : averageRating.toStringAsFixed(1),
            'Rating', Icons.star, Colors.amber),
      ],
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 3,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCalendarSection() {
    return Container(
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
      child: Column(
        children: [
          // 🔹 CUSTOM CALENDAR HEADER
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 12, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                    });
                  },
                  icon: Icon(Icons.chevron_left_rounded, color: Colors.grey[600], size: 24),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat.yMMMM().format(_focusedDay),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _focusedDay = DateTime.now();
                          _selectedDay = DateTime.now();
                        });
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
                IconButton(
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                    });
                  },
                  icon: Icon(Icons.chevron_right_rounded, color: Colors.grey[600], size: 24),
                ),
              ],
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            sixWeekMonthsEnforced: true,
            headerVisible: false, // Hide default header
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final dayKey = DateTime(day.year, day.month, day.day);
              return _events[dayKey] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
            ),
          ),
          if (_selectedDay != null && _events[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: (_events[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? [])
                    .map((event) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['serviceName'] ?? 'Booking',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      event['time'] ?? '',
                                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                event['status'] ?? '',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF4F46E5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
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
              fontSize: 18,
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
            _buildSectionHeader('New Service Requests', docs.isNotEmpty ? '${docs.length}' : '', () {}),
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
                itemCount: docs.length,
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
                            children: [
                              _infoBadge(Icons.calendar_today_outlined, data['date'] ?? 'No date'),
                              const SizedBox(width: 12),
                              _infoBadge(Icons.access_time_outlined, data['time'] ?? 'No time'),
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

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
