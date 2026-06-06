import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpCenterScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const HelpCenterScreen({super.key, required this.bookingData});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final Color primaryOrange = const Color(0xFFFF6B00);
  final TextEditingController _reportController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 FAQs
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildFAQs(),
            const SizedBox(height: 32),

            // 📝 Report a Problem
            Text(
              'REPORT A PROBLEM',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildReportForm(),
            const SizedBox(height: 40),


          ],
        ),
      ),
    );
  }

  Widget _buildFAQs() {
    final List<Map<String, String>> faqs = [
      {
        'q': 'My provider hasn\'t arrived yet',
        'a': 'If your provider is more than 15 minutes late, you can call them directly or contact our support team via Live Chat.'
      },
      {
        'q': 'How do I reschedule?',
        'a': 'Go to your booking details and click "Reschedule". Note that rescheduling within 24 hours of service may incur a fee.'
      },
      {
        'q': 'Can I cancel right now?',
        'a': 'Yes, you can cancel from the tracking screen. Free cancellations are available up to 24 hours before the service starts.'
      },
      {
        'q': 'Provider is at wrong address',
        'a': 'Use the chat button on the tracking screen to send them your correct location or a photo of your house entrance.'
      },
    ];

    return Column(
      children: faqs.map((faq) => _faqTile(faq['q']!, faq['a']!)).toList(),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            answer,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reportController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Briefly describe your problem...',
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
              border: InputBorder.none,
            ),
            style: GoogleFonts.outfit(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final String reportText = _reportController.text.trim();
                if (reportText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please describe your problem first.')),
                  );
                  return;
                }

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  String customerName = widget.bookingData['customerName'] ?? 'Anonymous';
                  String customerProfileUrl = '';
                  String customerCustomId = 'CU-PENDING';
                  
                  if (currentUser != null) {
                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                    if (userDoc.exists) {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      customerName = userData['name'] ?? customerName;
                      customerProfileUrl = userData['profileUrl'] ?? '';
                      customerCustomId = userData['customId'] ?? customerCustomId;
                    }
                  }

                  // Fetch Provider Custom ID
                  String providerCustomId = 'PR-PENDING';
                  final String providerId = widget.bookingData['providerId'] ?? '';
                  if (providerId.isNotEmpty) {
                    var providerDoc = await FirebaseFirestore.instance.collection('providers').doc(providerId).get();
                    if (!providerDoc.exists) {
                      providerDoc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
                    }
                    if (providerDoc.exists) {
                      providerCustomId = (providerDoc.data() as Map<String, dynamic>)['customId'] ?? providerCustomId;
                    }
                  }

                  await FirebaseFirestore.instance.collection('reports').add({
                    'orderId': widget.bookingData['orderId'] ?? 'GS-00000',
                    'bookingId': widget.bookingData['bookingId'] ?? widget.bookingData['id'] ?? 'N/A',
                    'serviceName': widget.bookingData['serviceName'] ?? 'Unknown',
                    'customerId': currentUser?.uid ?? '',
                    'customerCustomId': customerCustomId,
                    'customerName': customerName,
                    'customerProfileUrl': customerProfileUrl,
                    'providerId': providerId,
                    'providerCustomId': providerCustomId,
                    'providerName': widget.bookingData['providerName'] ?? 'N/A',
                    'issue': reportText,
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    _showSuccessDialog();
                    _reportController.clear();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to submit report. Please try again.')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Submit Report',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Report Sent!',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for your feedback. Our support team has received your report and will look into it immediately.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back from help center
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
