import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/profile_screen.dart';
import '../services/add_service.dart';
import '../profile/provider_reviews.dart';
import '../provider/my_services_screen.dart';
import '../provider/provider_activity_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? providerData;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _fetchProviderData();
  }

  Future<void> _fetchProviderData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('providers').doc(user!.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        providerData = doc.data();
        isOnline = providerData?['isOnline'] ?? true;
      });
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => isOnline = value);
    if (user != null) {
      await FirebaseFirestore.instance.collection('providers').doc(user!.uid).update({
        'isOnline': value,
      });
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
                  _buildSectionHeader('Up Next', 'View All', () {}),
                  const SizedBox(height: 16),
                  _buildUpcomingBookings(),
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
                    'Good Morning,',
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: (providerData?['profileUrl'] != null && providerData!['profileUrl'].isNotEmpty)
                    ? NetworkImage(providerData!['profileUrl'])
                    : null,
                child: (providerData?['profileUrl'] == null || providerData!['profileUrl'].isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
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
          _statItem('RM 1,240', 'Earnings', Icons.insights, Colors.blue),
          _statItem('24', 'Bookings', Icons.calendar_today, const Color(0xFF4F46E5)),
          _statItem('4.9', 'Rating', Icons.star, Colors.amber),
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
              fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
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

  Widget _buildUpcomingBookings() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'https://i.pravatar.cc/150?u=Hanim',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hanim',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Office Cleaning',
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            '10:00 AM Today',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF4F46E5),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const AddServiceScreen()));
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
              fontWeight: FontWeight.bold,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
