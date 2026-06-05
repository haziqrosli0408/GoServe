import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/single_chat_screen.dart';
import '../../services/onesignal_service.dart';


class ProviderServiceRequestsPage extends StatefulWidget {
  const ProviderServiceRequestsPage({super.key});

  @override
  State<ProviderServiceRequestsPage> createState() => _ProviderServiceRequestsPageState();
}

class _ProviderServiceRequestsPageState extends State<ProviderServiceRequestsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final Color themeColor = const Color(0xFF4F46E5);

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (newStatus == 'Confirmed') {
        try {
          final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
          final data = doc.data() as Map<String, dynamic>;
          final customerId = data['customerId'];
          
          final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(user?.uid).get();
          final providerName = providerDoc.data()?['name'] ?? 'A provider';
          
          await OneSignalService.notifyBookingConfirmed(
            customerId: customerId,
            providerName: providerName,
            serviceName: data['serviceName'] ?? 'Service',
            bookingId: bookingId,
          );
        } catch (e) {
          debugPrint('Error sending confirmation notification: $e');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $newStatus successfully'),
            backgroundColor: newStatus == 'Confirmed' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black87),
        title: Text(
          "New Service Requests",
          style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('providerId', isEqualTo: user?.uid)
                  .where('status', isEqualTo: 'Pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: Colors.grey[300], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No new requests',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
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

                        return GestureDetector(
                          onTap: () => _showBookingDetails(data, customerName, profileUrl, customerPhone),
                          child: Container(
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
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          data['serviceName'] ?? 'Service',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Order ID: ${data['orderId'] ?? 'N/A'}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    data['totalPrice'] != null ? data['totalPrice'].toString() : 'RM ${(data['price'] ?? 0)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: themeColor,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['date'] ?? 'No date',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_outlined, size: 16, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['time'] ?? 'No time',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _updateBookingStatus(doc.id, 'Rejected');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Decline',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _updateBookingStatus(doc.id, 'Confirmed');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        backgroundColor: themeColor,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Accept',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
                  );
                }
              );
              },
            ),
    );
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
                                  fontWeight: FontWeight.w500,
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
