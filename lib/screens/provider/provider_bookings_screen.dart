import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/location_service.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen> {
  String selectedFilter = 'Requests';
  final filters = ['Requests', 'Upcoming', 'Completed', 'Cancelled'];
  final LocationService _locationService = LocationService();
  final String currentProviderId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4F46E5),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildFilters(),
                  Expanded(
                    child: _buildBookingsList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track and manage your service requests',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingsList() {
    if (currentProviderId.isEmpty) return const Center(child: Text('Please login'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: currentProviderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          
          if (selectedFilter == 'Requests') return status == 'Pending';
          if (selectedFilter == 'Upcoming') return ['Confirmed', 'On the way', 'Arrived', 'In progress'].contains(status);
          if (selectedFilter == 'Completed') return status == 'Completed';
          if (selectedFilter == 'Cancelled') return status == 'Cancelled';
          return true; // For 'All' - though we don't have 'All' anymore explicitly
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No bookings found',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            return _buildBookingCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(String bookingId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Confirmed';
    
    final String customerId = data['customerId'] ?? '';
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
      builder: (context, snapshot) {
        String customerName = 'Unknown Customer';
        String? profileUrl;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName = userData['name'] ?? 'Customer';
          profileUrl = userData['profileUrl'];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
               BoxShadow(
                 color: Colors.black.withValues(alpha: 0.01),
                 blurRadius: 10,
                 offset: const Offset(0, 4),
               ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                    child: profileUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
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
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'RM ${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4F46E5),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: data['serviceImage'] != null
                                      ? Image.network(
                                          data['serviceImage'],
                                          width: 35,
                                          height: 35,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 35,
                                          height: 35,
                                          color: Colors.grey[100],
                                          child: const Icon(Icons.cleaning_services, size: 16, color: Colors.grey),
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
              const Divider(height: 24),
              Row(
                children: [
                  _infoTile(Icons.calendar_today, data['date'] ?? 'No date'),
                  const Spacer(),
                  _infoTile(Icons.access_time, data['time'] ?? 'No time'),
                ],
              ),
              const SizedBox(height: 16),
              _buildActionButton(bookingId, status),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActionButton(String bookingId, String status) {
    if (status == 'Pending') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('Details', const Color(0xFFF1F5F9), const Color(0xFF1E293B), () {
              // View Details logic
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn('Accept', const Color(0xFF4F46E5), Colors.white, () {
              _updateBookingStatus(bookingId, 'Confirmed');
            }),
          ),
        ],
      );
    } else if (status == 'Confirmed') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('On the way', const Color(0xFF4F46E5), Colors.white, () {
              _updateBookingStatus(bookingId, 'On the way');
              _locationService.startTracking(bookingId);
            }),
          ),
        ],
      );
    } else if (status == 'On the way') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('Arrived', const Color(0xFF10B981), Colors.white, () {
              _updateBookingStatus(bookingId, 'Arrived');
              _locationService.stopTracking();
            }),
          ),
        ],
      );
    } else if (status == 'Arrived') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('Start Work', const Color(0xFFF59E0B), Colors.white, () {
              _updateBookingStatus(bookingId, 'In progress');
            }),
          ),
        ],
      );
    } else if (status == 'In progress') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('Complete Job', const Color(0xFF4F46E5), Colors.white, () {
              _updateBookingStatus(bookingId, 'Completed');
            }),
          ),
        ],
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _updateBookingStatus(String bookingId, String status) {
    FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'status': status,
    });
  }

  Widget _infoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color bg, Color text, VoidCallback onTap, {bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: Colors.grey.shade300) : null,
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(color: text, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
