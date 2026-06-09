import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'booking_cancelled_screen.dart';
import '../../services/onesignal_service.dart';

class CancelBookingSheet extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const CancelBookingSheet({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends State<CancelBookingSheet> {
  String? selectedReason;
  bool isOtherSelected = false;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _isProcessing = false;

  final List<String> cancelReasons = [
    'Change of plans',
    'Found another provider',
    'Emergency / personal reasons',
    'Provider took too long to confirm',
    'Other',
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _processCancellation() async {
    if (selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for cancellation')),
      );
      return;
    }

    if (isOtherSelected && _otherReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify your reason')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final String finalReason = isOtherSelected
        ? 'Other: ${_otherReasonController.text.trim()}'
        : selectedReason!;

    try {
      // 1. Update booking status
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer',
        'cancellationReason': finalReason,
        'refundAmount': widget.bookingData['totalPrice'] ?? 0.0,
        'refundStatus': 'pending',
      });

      // 2. Notify Provider via in-app notification
      final String providerId = widget.bookingData['providerId'] ?? '';
      if (providerId.isNotEmpty) {
         await FirebaseFirestore.instance.collection('notifications').add({
          'userId': providerId,
          'type': 'booking_cancelled',
          'title': 'Booking Cancelled',
          'body': 'A customer has cancelled the booking for ${widget.bookingData['serviceName']} on ${widget.bookingData['date']}.',
          'bookingId': widget.bookingId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // 🔔 Send push notification to Provider
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.bookingData['customerId'] ?? '').get();
        final customerName = userDoc.exists ? (userDoc.data()?['name'] ?? 'A customer') : 'A customer';
        
        await OneSignalService.notifyBookingCancelled(
          providerId: providerId,
          customerName: customerName,
          serviceName: widget.bookingData['serviceName'] ?? 'Service',
          bookingId: widget.bookingId,
        );
      }

      if (mounted) {
        // Navigate to the success screen, removing previous bottom sheets/dialogs
        Navigator.pop(context); // Close sheet
        Navigator.pop(context); // Close booking details modal if open
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const BookingCancelledScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if it's safe to cancel
    final String currentStatus = widget.bookingData['status'] ?? '';
    bool canCancel = ['Pending', 'Confirmed', 'Awaiting Confirmation'].contains(currentStatus);
    String rejectReason = 'This booking can no longer be cancelled as the provider has already started the service.';

    if (canCancel && currentStatus != 'Pending') {
      try {
        String dateStr = widget.bookingData['date'] ?? '';
        String timeStr = widget.bookingData['time'] ?? '';
        DateTime? bookingTime;
        try {
          // Add DateFormat parsing support
          bookingTime = DateFormat('yyyy-MM-dd h:mm a').parse('$dateStr $timeStr');
        } catch (_) {
          try {
            bookingTime = DateFormat('MMM dd, yyyy h:mm a').parse('$dateStr $timeStr');
          } catch (_) {}
        }
        
        if (bookingTime != null) {
          if (bookingTime.difference(DateTime.now()).inHours < 24) {
            canCancel = false;
            rejectReason = 'This booking cannot be cancelled because it is less than 24 hours before the scheduled service time.';
          }
        }
      } catch (_) {}
    }

    if (!canCancel) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Cannot Cancel Booking',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rejectReason,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      );
    }

    final double totalPrice = (widget.bookingData['totalPrice'] as num?)?.toDouble() ?? 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
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
                    'Cancel Booking',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please tell us why you are cancelling. This helps us improve our service.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Reasons List
                  Text(
                    'Reason for cancellation',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...cancelReasons.map((reason) {
                    final bool isSelected = selectedReason == reason;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedReason = reason;
                          isOtherSelected = reason == 'Other';
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red.shade50 : Colors.white,
                          border: Border.all(
                            color: isSelected ? Colors.red.shade200 : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.red.shade400 : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                reason,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Other Text Field
                  if (isOtherSelected) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otherReasonController,
                      decoration: InputDecoration(
                        hintText: 'Please specify...',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Refund Summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Refund Summary',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _summaryRow('Total Paid', 'RM ${totalPrice.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _summaryRow('Cancellation Fee', 'RM 0.00'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Refund Amount',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'RM ${totalPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Refunds are processed to your original payment method within 3-5 business days.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Keep Booking',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processCancellation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Confirm Cancel',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
