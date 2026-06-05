import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'active_service_screen.dart';
import 'service_start_animation_screen.dart';

import 'package:intl/intl.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen> {
  String selectedFilter = 'Active';
  final filters = ['Active', 'Past'];
  final String currentProviderId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
      child: Center(
        child: Text(
          'Activity',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Stack(
        children: [
          Row(
            children: filters.map((filter) {
              final isSelected = selectedFilter == filter;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedFilter = filter),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Animated Underline Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 0,
            left: selectedFilter == 'Active' ? 0 : MediaQuery.of(context).size.width / 2,
            child: Container(
              height: 3,
              width: MediaQuery.of(context).size.width / 2,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
            ),
          ),
        ],
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
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final todayHumanStr = DateFormat('d MMM yyyy').format(now);

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          final dateStr = data['date']?.toString() ?? '';
          
          // Normalize date string for comparison
          bool isToday = false;
          try {
            // Check for yyyy-MM-dd format
            if (dateStr.contains(todayStr)) isToday = true;
            // Check for "12 Apr 2026" style format
            if (dateStr.toLowerCase().contains(todayHumanStr.toLowerCase())) isToday = true;
          } catch (_) {}

          if (selectedFilter == 'Active') {
            // Confirmed, On the way, Arrived, In progress + Completed Today
            if (['Confirmed', 'On the way', 'Arrived', 'In progress'].contains(status)) return true;
            if (status == 'Completed' && isToday) return true;
            return false;
          } else {
            // Past: Completed (not today) + Cancelled
            if (status == 'Cancelled') return true;
            if (status == 'Completed' && !isToday) return true;
            return false;
          }
        }).toList();

        // Sort by createdAt descending
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

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
        String? customerPhone;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName = userData['name'] ?? 'Customer';
          profileUrl = userData['profileUrl'];
          customerPhone = userData['phone'];
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
                  ClipOval(
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[100],
                      child: profileUrl != null && profileUrl.isNotEmpty
                          ? Image.network(
                              profileUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person, color: Colors.grey),
                            )
                          : const Icon(Icons.person, color: Colors.grey),
                    ),
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
                                    style: GoogleFonts.outfit(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order ID: ${data['orderId'] ?? 'GS-00000'}',
                                    style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final double basePrice = (data['basePrice'] is num) ? (data['basePrice'] as num).toDouble() : (double.tryParse(data['basePrice'].toString()) ?? 0.0);
                                    final List addOns = data['selectedAddOns'] ?? [];
                                    double addOnsTotal = 0;
                                    for (var addon in addOns) {
                                      final price = addon['price'];
                                      addOnsTotal += (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0.0);
                                    }
                                    
                                    double earnings = basePrice + addOnsTotal;
                                    // Fallback for older bookings
                                    if (earnings == 0 && data['totalPrice'] != null) {
                                      final double total = double.tryParse(data['totalPrice'].toString().replaceAll('RM', '').trim()) ?? 0.0;
                                      earnings = total / 1.15;
                                    }
                                    
                                    return Text(
                                      'RM ${earnings.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4F46E5),
                                        fontSize: 16,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: data['serviceImage'] != null && data['serviceImage'].toString().isNotEmpty
                                      ? Image.network(
                                          data['serviceImage'],
                                          width: 35,
                                          height: 35,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 35,
                                            height: 35,
                                            color: Colors.grey[100],
                                            child: const Icon(Icons.cleaning_services, size: 16, color: Colors.grey),
                                          ),
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
              _buildActionButton(bookingId, status, data, customerName, profileUrl, customerPhone),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActionButton(String bookingId, String status, Map<String, dynamic> data, String customerName, String? profileUrl, String? customerPhone) {
    if (status == 'Pending' || status == 'Awaiting Confirmation') {
      return Row(
        children: [
          Expanded(
            child: _actionBtn('Reject', Colors.white, Colors.red.shade500, () {
              _rejectBooking(bookingId, data);
            }, isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionBtn('Accept', const Color(0xFF4F46E5), Colors.white, () {
              _updateBookingStatus(bookingId, 'Confirmed');
            }),
          ),
        ],
      );
    } else if (['Confirmed', 'On the way', 'Arrived', 'In progress'].contains(status)) {
      return Row(
        children: [
          Expanded(
            child: _actionBtn(
              status == 'Confirmed' ? 'Start' : 'Continue', 
              const Color(0xFF4F46E5), 
              Colors.white, 
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => (status == 'Confirmed')
                        ? ServiceStartAnimationScreen(
                            bookingId: bookingId,
                            bookingData: data,
                          )
                        : ActiveServiceScreen(
                            bookingId: bookingId,
                            bookingData: data,
                          ),
                  ),
                );
              }
            ),
          ),
        ],
      );
    } else if (status == 'Cancelled') {
      String cancelReason = data['cancellationReason'] ?? 'No reason provided';
      String cancelledBy = data['cancelledBy'] ?? 'customer';
      bool byProvider = cancelledBy == 'provider';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Text(
                  byProvider ? 'Rejected by You' : 'Cancelled by Customer',
                  style: GoogleFonts.outfit(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: $cancelReason',
              style: GoogleFonts.outfit(
                color: Colors.red.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'Completed') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Service Completed',
              style: GoogleFonts.outfit(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

  void _rejectBooking(String bookingId, Map<String, dynamic> data) async {
    // Show confirmation dialog before rejecting
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Booking', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to reject this booking? This action cannot be undone.', style: GoogleFonts.outfit()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Reject', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'provider',
        'cancellationReason': 'Provider unavailable / rejected request',
        'refundAmount': data['totalPrice'] ?? 0.0,
        'refundStatus': 'pending',
      });

      // Notify Customer
      String customerId = data['customerId'] ?? '';
      if (customerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customerId,
          'type': 'booking_rejected',
          'title': 'Booking Rejected',
          'body': 'Your booking for ${data['serviceName']} was rejected by the provider. You will receive a full refund.',
          'bookingId': bookingId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          border: isOutlined ? Border.all(color: text.withValues(alpha: 0.5), width: 1.5) : null,
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

  // Removed duplicated _buildActionButton
}
