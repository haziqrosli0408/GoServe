import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/single_chat_screen.dart';
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
            // Pending, Awaiting Confirmation, Confirmed, On the way, Arrived, In progress + Completed Today
            if (['Pending', 'Awaiting Confirmation', 'Confirmed', 'On the way', 'Arrived', 'In progress'].contains(status)) return true;
            if (status == 'Completed' && isToday) return true;
            return false;
          } else {
            // Past: Completed (not today) + Cancelled
            if (status == 'Cancelled') return true;
            if (status == 'Completed' && !isToday) return true;
            return false;
          }
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
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            
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
                          ClipOval(
                            child: Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey[100],
                              child: (profileUrl != null && profileUrl.isNotEmpty)
                                  ? Image.network(
                                      profileUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, color: Color(0xFF4F46E5)),
                                    )
                                  : const Icon(Icons.person, color: Color(0xFF4F46E5)),
                            ),
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
                      const Divider(height: 24,),
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
                              
                              double totalEarnings = basePrice + addOnsTotal;
                              // Fallback for older bookings
                              if (totalEarnings == 0 && data['totalPrice'] != null) {
                                final double total = double.tryParse(data['totalPrice'].toString().replaceAll('RM', '').trim()) ?? 0.0;
                                totalEarnings = total / 1.15;
                              }
                              
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              SizedBox(
                width: 230,
                child: Text(
                  value, 
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                  maxLines: isExpandable ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
