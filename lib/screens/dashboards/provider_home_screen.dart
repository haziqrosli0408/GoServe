import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/profile_screen.dart';

import '../profile/provider_reviews.dart';
import '../provider/my_services_screen.dart';
import '../provider/provider_activity_screen.dart';
import '../provider/service_selector.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? providerData;
  bool isOnline = true;

  // Real Stats
  double totalEarnings = 0.0;
  int totalBookings = 0;
  double averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProviderData();
    _fetchProviderStats();
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
        isOnline = providerData?['isOnline'] ?? true;
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

    // 2. Calculate Total Earnings (from completed bookings)
    FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'Completed')
        .get()
        .then((snapshot) {
      if (mounted) {
        double total = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final priceStr = data['totalPrice'] ?? data['price'] ?? '0';
          final cleanPrice = priceStr.toString().replaceAll('RM', '').trim();
          total += double.tryParse(cleanPrice) ?? 0.0;
        }
        setState(() => totalEarnings = total);
      }
    });

    // 3. Calculate Average Rating
    FirebaseFirestore.instance
        .collection('reviews')
        .where('providerId', isEqualTo: user!.uid)
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

  Future<void> _toggleOnline(bool value) async {
    setState(() => isOnline = value);
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(user!.uid)
          .update({
        'isOnline': value,
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: providerData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildAvailabilityCard(),
                  const SizedBox(height: 24),
                  _buildNewRequestsSection(),
                  const SizedBox(height: 24),

                  _buildQuickActions(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4F46E5).withValues(alpha: 0.15),
            Colors.white,
          ],
        ),
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
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    providerData?['name'] ?? 'Provider',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E293B),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
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
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white,
                  backgroundImage: (providerData?['profileUrl'] != null && providerData!['profileUrl'].toString().isNotEmpty)
                      ? NetworkImage(providerData!['profileUrl'])
                      : null,
                  child: (providerData?['profileUrl'] == null || providerData!['profileUrl'].toString().isEmpty)
                      ? Text(
                          (providerData?['name'] ?? 'P')[0].toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4F46E5),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
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
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 3,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isOnline ? const Color(0xFFE6FFFA) : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isOnline ? Colors.teal.shade50 : Colors.red.shade50),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOnline ? Colors.teal : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(isOnline ? Icons.power_settings_new : Icons.power_off, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are Online' : 'You are Offline',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isOnline ? Colors.teal.shade900 : Colors.red.shade900,
                    ),
                  ),
                  Text(
                    isOnline ? 'Customers can see and book you' : 'Switch online to receive bookings',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: isOnline ? Colors.teal.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOnline,
              activeColor: Colors.teal,
              onChanged: _toggleOnline,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Quick Actions', '', () {}),
          const SizedBox(height: 16),
          Row(
            children: [
              _actionCard('Add Service', Icons.add_circle_outline, Colors.indigo, () {
                 ServiceSelector.show(context);
              }),
              const SizedBox(width: 12),
              _actionCard('My Reviews', Icons.star_outline, Colors.amber, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderReviewsPage()));
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionCard('My Services', Icons.storefront_outlined, Colors.indigo, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MyServicesScreen()));
              }),
              const SizedBox(width: 12),
              _actionCard('Activity', Icons.local_activity_rounded, Colors.teal, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderActivityScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('New Service Requests', '${snapshot.data!.docs.length}', () {}),
            const SizedBox(height: 16),
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String customerId = data['customerId'] ?? '';

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
                    builder: (context, userSnapshot) {
                      String customerName = 'Customer';
                      String? profileUrl;
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        customerName = userData['name'] ?? 'Customer';
                        profileUrl = userData['profileUrl'];
                      }

                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
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
                                  radius: 20,
                                  backgroundColor: Colors.grey[100],
                                  backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                                  child: profileUrl == null ? const Icon(Icons.person, color: Colors.grey, size: 20) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48, // Fixed height for text section to align all cards
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          customerName,
                                          style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          data['serviceName'] ?? 'Service',
                                          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: data['serviceImage'] != null
                                      ? Image.network(
                                          data['serviceImage'],
                                          width: 45,
                                          height: 45,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 45,
                                          height: 45,
                                          color: Colors.grey[100],
                                          child: const Icon(Icons.cleaning_services, size: 20, color: Colors.grey),
                                        ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['date'] ?? 'No date',
                                        style: GoogleFonts.outfit(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['time'] ?? 'No time',
                                        style: GoogleFonts.outfit(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF1E293B),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Details'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updateBookingStatus(doc.id, 'Confirmed'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Accept'),
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
}
