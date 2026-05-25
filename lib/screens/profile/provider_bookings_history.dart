import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProviderBookingsHistoryPage extends StatefulWidget {
  const ProviderBookingsHistoryPage({super.key});

  @override
  State<ProviderBookingsHistoryPage> createState() => _ProviderBookingsHistoryPageState();
}

class _ProviderBookingsHistoryPageState extends State<ProviderBookingsHistoryPage> {
  final Color themeColor = const Color(0xFF4F46E5); // Provider Indigo
  String activeFilter = 'All';

  final user = FirebaseAuth.instance.currentUser;

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Completed':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'In progress':
      case 'Accepted':
      case 'On the way':
      case 'Arrived':
      case 'Work in Progress':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        status = 'In Progress'; // Normalize for display
        break;
      case 'Cancelled':
      case 'Rejected':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'Pending':
      case 'Awaiting Confirmation':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black87),
        title: Text(
          "Bookings History",
          style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterHeader(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('providerId', isEqualTo: user!.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      var bookingsWithId = snapshot.data!.docs.map((doc) => {
                        'id': doc.id,
                        'data': doc.data() as Map<String, dynamic>
                      }).toList();

                      // Sort by createdAt descending
                      bookingsWithId.sort((a, b) {
                        final aData = a['data'] as Map<String, dynamic>;
                        final bData = b['data'] as Map<String, dynamic>;
                        final aTime = aData['createdAt'] as Timestamp?;
                        final bTime = bData['createdAt'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      // Apply filter
                      if (activeFilter != 'All') {
                        bookingsWithId = bookingsWithId.where((b) {
                          String status = (b['data'] as Map<String, dynamic>)['status'] ?? '';
                          if (activeFilter == 'Completed' && status == 'Completed') return true;
                          if (activeFilter == 'Cancelled' && (status == 'Cancelled' || status == 'Rejected')) return true;
                          if (activeFilter == 'In Progress' && 
                              ['In progress', 'Accepted', 'On the way', 'Arrived', 'Work in Progress', 'Pending', 'Awaiting Confirmation'].contains(status)) {
                            return true;
                          }
                          return false;
                        }).toList();
                      }

                      if (bookingsWithId.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        itemCount: bookingsWithId.length,
                        itemBuilder: (context, index) {
                          final bookingMap = bookingsWithId[index];
                          return _buildBookingCard(bookingMap['id'] as String, bookingMap['data'] as Map<String, dynamic>);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No bookings found",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "There are no bookings matching the selected filter.",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    final filters = ['All', 'In Progress', 'Completed', 'Cancelled'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((filter) {
            final isSelected = activeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: GoogleFonts.outfit(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => activeFilter = filter);
                },
                selectedColor: themeColor,
                backgroundColor: Colors.grey.shade100,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBookingCard(String bookingId, Map<String, dynamic> booking) {
    final serviceName = booking['serviceName'] ?? 'Unknown Service';
    final customerId = booking['customerId'] ?? '';
    final date = booking['date'] ?? '';
    final time = booking['time'] ?? '';
    final status = booking['status'] ?? 'Unknown';
    final priceStr = (booking['totalPrice'] ?? booking['price'] ?? '0').toString();
    
    // Attempt to format timestamp if available
    String displayDate = date;
    if (booking['createdAt'] != null && date.isEmpty) {
      final dt = (booking['createdAt'] as Timestamp).toDate();
      displayDate = DateFormat('MMM d, yyyy').format(dt);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
      builder: (context, snapshot) {
        String customerName = booking['customerName'] ?? 'Customer';
        String profileUrl = booking['customerProfileUrl'] ?? booking['profileUrl'] ?? '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName = userData['name'] ?? customerName;
          profileUrl = userData['profileUrl'] ?? profileUrl;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                          serviceName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Order #${booking['orderId'] ?? 'GS-00000'}",
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                    child: profileUrl.isEmpty
                        ? Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    customerName,
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        "$displayDate, $time",
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    priceStr.startsWith('RM') ? priceStr : 'RM $priceStr',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
