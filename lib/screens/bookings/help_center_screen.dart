import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

            // 📞 Contact Footer
            _buildContactFooter(),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. We will contact you shortly.')),
                );
                _reportController.clear();
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

  Widget _buildContactFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _contactOption(Icons.email_outlined, 'Email Us'),
            const SizedBox(width: 40),
            _contactOption(Icons.phone_rounded, 'Contact us'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'We typically respond within 1 hour',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _contactOption(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
