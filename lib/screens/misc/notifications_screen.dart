import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final Color themeColor;
  const NotificationsScreen({super.key, this.themeColor = const Color(0xFFFF6B00)});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  bool isProvider = false;

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    if (userId == null) return;
    final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(userId).get();
    if (mounted) {
      setState(() {
        isProvider = providerDoc.exists;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: userId == null 
        ? _buildEmptyState() 
        : StreamBuilder<QuerySnapshot>(
            stream: isProvider 
              ? FirebaseFirestore.instance
                  .collection('bookings')
                  .where('providerId', isEqualTo: userId)
                  .where('status', isEqualTo: 'Pending')
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: userId)
                  .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _buildNotificationItem(data);
                },
              );
            },
          ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> data) {
    final String status = data['status'] ?? 'Unknown';
    final String serviceName = data['serviceName'] ?? 'Service';
    final String orderId = data['orderId'] ?? 'GS-0000';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeStr = timestamp != null 
        ? DateFormat('d MMM, h:mm a').format(timestamp.toDate())
        : 'Just now';

    IconData iconData = Icons.notifications_active;
    Color iconColor = widget.themeColor;
    String title = "";
    String body = "";

    if (isProvider) {
      if (status == 'Pending') {
        iconData = Icons.new_releases;
        iconColor = Colors.red;
        title = "New Service Request!";
        body = "You have a new request for $serviceName ($orderId). Check it now!";
      } else {
        iconData = Icons.info_outline;
        iconColor = Colors.blue;
        title = "Booking Update";
        body = "Booking $orderId status changed to $status.";
      }
    } else {
      if (status == 'Pending') {
        iconData = Icons.hourglass_empty;
        iconColor = Colors.orange;
        title = "Request Sent";
        body = "Your request for $serviceName has been sent and is awaiting provider approval.";
      } else if (status == 'Accepted' || status == 'Confirmed') {
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        title = "Booking Accepted";
        body = "Your booking for $serviceName has been accepted by the provider.";
      } else if (status == 'On the way') {
        iconData = Icons.moped;
        iconColor = Colors.blue;
        title = "Provider on the way";
        body = "Your provider is heading to your location for $serviceName.";
      } else if (status == 'Completed') {
        iconData = Icons.stars;
        iconColor = Colors.amber;
        title = "Service Completed";
        body = "Hope you enjoyed your $serviceName! Please leave a review.";
      } else {
        iconData = Icons.info_outline;
        iconColor = Colors.blue;
        title = "Booking Update";
        body = "Your booking for $serviceName is now: $status.";
      }
    }

    if (title.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
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
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Stay tuned! We'll notify you here when something happens.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
