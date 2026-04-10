import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProviderActivityScreen extends StatelessWidget {
  const ProviderActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildActivityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
      ),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            'Stay updated with your latest transactions',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    // Mock data for activities
    final activities = [
      {
        'type': 'payment_received',
        'title': 'Payment Received',
        'description': 'RM 85.00 received from Alice for Deep House Cleaning',
        'time': '2 mins ago',
        'isNew': true,
      },
      {
        'type': 'service_request',
        'title': 'New Service Request',
        'description': 'Hanim requested for Office Cleaning on Dec 30',
        'time': '1 hour ago',
        'isNew': true,
      },
      {
        'type': 'review',
        'title': 'New 5-Star Review!',
        'description': 'John Smith left a review: "Excellent work, very professional!"',
        'time': '3 hours ago',
        'isNew': false,
      },
      {
        'type': 'service_completed',
        'title': 'Service Completed',
        'description': 'Job #BK001 for Sarah Wilson has been marked as completed',
        'time': 'Yesterday',
        'isNew': false,
      },
      {
        'type': 'payment_received',
        'title': 'Payment Received',
        'description': 'RM 120.00 received from Michael for Electrical Wiring',
        'time': 'Yesterday',
        'isNew': false,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityItem(activity);
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (activity['type']) {
      case 'payment_received':
        icon = Icons.account_balance_wallet_rounded;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF166534);
        break;
      case 'service_request':
        icon = Icons.receipt_long_rounded;
        iconBg = const Color(0xFFE0E7FF);
        iconColor = const Color(0xFF3730A3);
        break;
      case 'review':
        icon = Icons.star_rounded;
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFF92400E);
        break;
      case 'service_completed':
        icon = Icons.check_circle_rounded;
        iconBg = const Color(0xFFCCFBF1);
        iconColor = const Color(0xFF0F766E);
        break;
      default:
        icon = Icons.notifications_rounded;
        iconBg = Colors.grey.shade100;
        iconColor = Colors.grey.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activity['isNew'] ? const Color(0xFF4F46E5).withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activity['isNew'] ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.grey.shade100,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
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
                      activity['title'],
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (activity['isNew'])
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'],
                  style: GoogleFonts.outfit(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activity['time'],
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
