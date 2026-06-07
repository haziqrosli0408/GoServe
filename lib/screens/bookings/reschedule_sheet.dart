import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RescheduleSheet extends StatefulWidget {
  final String bookingId;
  final String currentDate;
  final String currentTime;
  final String serviceId;

  const RescheduleSheet({
    super.key,
    required this.bookingId,
    required this.currentDate,
    required this.currentTime,
    required this.serviceId,
  });

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  late DateTime selectedDate;
  String? selectedTime;
  final Color primaryOrange = const Color(0xFFFF6B00);

  bool _isLoadingAvailability = true;
  Map<String, List<String>> _serviceAvailability = {};

  List<String> get _slotsForSelectedDate {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    return _serviceAvailability[key] ?? [];
  }

  bool _hasAvailability(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    return (_serviceAvailability[key] ?? []).isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // Parse current date if possible, otherwise use now
    try {
      selectedDate = DateFormat('MMM dd, yyyy').parse(widget.currentDate);
    } catch (e) {
      selectedDate = DateTime.now();
    }
    selectedTime = widget.currentTime;
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      if (widget.serviceId.isEmpty) {
        if (mounted) setState(() => _isLoadingAvailability = false);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();
      if (doc.exists) {
        final rawMap = doc.data()?['availability'] as Map<String, dynamic>? ?? {};
        final parsed = <String, List<String>>{};
        rawMap.forEach((date, slots) {
          parsed[date] = List<String>.from(slots as List);
        });
        if (mounted) {
          setState(() {
            _serviceAvailability = parsed;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    }
    if (mounted) setState(() => _isLoadingAvailability = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Reschedule Booking',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            'Select a new date and time for your service',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // Date Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Date',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('MMMM yyyy').format(selectedDate),
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCalendar(),
          
          const SizedBox(height: 24),

          // Time Selection
          Text(
            'Available Times',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_isLoadingAvailability)
            const Center(child: CircularProgressIndicator())
          else if (_serviceAvailability.isNotEmpty && _slotsForSelectedDate.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.orange.shade400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No time slots available for this date. Please select another date.',
                      style: GoogleFonts.outfit(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: (_serviceAvailability.isNotEmpty ? _slotsForSelectedDate : [
                  '08:00 AM', '09:30 AM', '11:00 AM', '01:30 PM', '03:00 PM', '04:30 PM', '06:00 PM'
                ]).map((time) => _timeSlot(time)).toList(),
              ),
            ),

          const SizedBox(height: 32),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _rescheduleBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Confirm Reschedule',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
    int blankDays = firstDayOfMonth.weekday - 1; 

    List<Widget> gridItems = [];
    for (var day in ['M', 'T', 'W', 'T', 'F', 'S', 'S']) {
      gridItems.add(Center(child: Text(day, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400))));
    }
    for (int i = 0; i < blankDays; i++) {
      gridItems.add(const SizedBox());
    }
    for (int d = 1; d <= lastDayOfMonth.day; d++) {
      final date = DateTime(selectedDate.year, selectedDate.month, d);
      final isPast = date.isBefore(today);
      final isSelected = selectedDate.day == d && selectedDate.month == date.month;
      final hasProviderAvailability = _serviceAvailability.isNotEmpty;
      final hasSlots = hasProviderAvailability ? _hasAvailability(date) : true;
      final isUnavailable = hasProviderAvailability && !hasSlots && !isPast;
      
      gridItems.add(GestureDetector(
        onTap: (isPast || isUnavailable) ? null : () => setState(() {
          selectedDate = date;
          selectedTime = null; // Clear time selection on new date
        }),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: date.day == today.day && date.month == today.month ? Border.all(color: primaryOrange.withValues(alpha: 0.3)) : null,
          ),
          child: Center(
            child: Text(
              '$d',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isPast || isUnavailable ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
          ),
        ),
      ));
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.5,
      children: gridItems,
    );
  }

  Widget _timeSlot(String time) {
    bool isSelected = selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => selectedTime = time),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? primaryOrange : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            time,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleBooking() async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available time slot.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'date': DateFormat('MMM dd, yyyy').format(selectedDate),
        'time': selectedTime,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking rescheduled to ${DateFormat('MMM dd').format(selectedDate)} at $selectedTime'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reschedule. Please try again.')),
        );
      }
    }
  }
}
