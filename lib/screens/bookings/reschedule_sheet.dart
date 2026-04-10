import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RescheduleSheet extends StatefulWidget {
  final String bookingId;
  final String currentDate;
  final String currentTime;

  const RescheduleSheet({
    super.key,
    required this.bookingId,
    required this.currentDate,
    required this.currentTime,
  });

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  late DateTime selectedDate;
  String? selectedTime;
  final Color primaryOrange = const Color(0xFFFF6B00);

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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _timeSlot('08:00 AM'),
                _timeSlot('09:30 AM'),
                _timeSlot('11:00 AM'),
                _timeSlot('01:30 PM'),
                _timeSlot('03:00 PM'),
                _timeSlot('04:30 PM'),
                _timeSlot('06:00 PM'),
              ],
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
      
      gridItems.add(GestureDetector(
        onTap: isPast ? null : () => setState(() => selectedDate = date),
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
                color: isSelected ? Colors.white : (isPast ? Colors.grey.shade300 : Colors.black87),
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
