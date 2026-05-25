import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceAvailabilitySheet extends StatefulWidget {
  final String serviceId;
  final String serviceTitle;

  const ServiceAvailabilitySheet({
    super.key,
    required this.serviceId,
    required this.serviceTitle,
  });

  @override
  State<ServiceAvailabilitySheet> createState() =>
      _ServiceAvailabilitySheetState();
}

class _ServiceAvailabilitySheetState extends State<ServiceAvailabilitySheet> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;

  // Map of "yyyy-MM-dd" → Set<String> of enabled time slots
  Map<String, Set<String>> _availability = {};
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _allSlots = [
    '08:00 AM',
    '09:30 AM',
    '11:00 AM',
    '01:30 PM',
    '03:00 PM',
    '04:30 PM',
    '06:00 PM',
    '07:30 PM',
    '09:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();
      if (doc.exists) {
        final rawMap = doc.data()?['availability'] as Map<String, dynamic>? ?? {};
        final parsed = <String, Set<String>>{};
        rawMap.forEach((date, slots) {
          parsed[date] = Set<String>.from(slots as List);
        });
        setState(() => _availability = parsed);
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);
    try {
      // Convert Set<String> → List<String> for Firestore
      final toSave = _availability.map((k, v) => MapEntry(k, v.toList()));
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .update({'availability': toSave});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Availability saved!',
                style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: primaryIndigo,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Set<String> _getSlotsForDate(DateTime d) =>
      _availability[_dateKey(d)] ?? {};

  void _toggleSlot(DateTime date, String slot) {
    final key = _dateKey(date);
    setState(() {
      _availability.putIfAbsent(key, () => {});
      if (_availability[key]!.contains(slot)) {
        _availability[key]!.remove(slot);
        if (_availability[key]!.isEmpty) _availability.remove(key);
      } else {
        _availability[key]!.add(slot);
      }
    });
  }

  bool _hasAvailability(DateTime d) =>
      (_availability[_dateKey(d)] ?? {}).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthCalendar(),
                    const SizedBox(height: 20),
                    if (_selectedDate != null) _buildTimeSlotsPanel(),
                    const SizedBox(height: 20),
                    _buildSummary(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Availability',
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(widget.serviceTitle,
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryIndigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: primaryIndigo, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${_availability.length} days set',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryIndigo)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildMonthCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final last = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final blankDays = first.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Month nav
          Row(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.chevron_left, color: Color(0xFF64748B)),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month - 1);
                  _selectedDate = null;
                }),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B)),
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month + 1);
                  _selectedDate = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day headers
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1.0),
            itemCount: blankDays + last.day,
            itemBuilder: (_, i) {
              if (i < blankDays) return const SizedBox();
              final day = i - blankDays + 1;
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final isPast = date.isBefore(today);
              final isSelected = _selectedDate != null &&
                  _dateKey(date) == _dateKey(_selectedDate!);
              final hasSlots = _hasAvailability(date);

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () => setState(() =>
                        _selectedDate = isSelected ? null : date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryIndigo
                        : hasSlots
                            ? primaryIndigo.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: isSelected || hasSlots
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isPast
                                  ? Colors.grey.shade200
                                  : hasSlots
                                      ? primaryIndigo
                                      : Colors.black87,
                        ),
                      ),
                      if (hasSlots && !isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: primaryIndigo, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsPanel() {
    final enabledSlots = _getSlotsForDate(_selectedDate!);
    final sections = [
      {
        'label': 'MORNING',
        'icon': Icons.wb_sunny_outlined,
        'slots': ['08:00 AM', '09:30 AM', '11:00 AM'],
      },
      {
        'label': 'AFTERNOON',
        'icon': Icons.sunny,
        'slots': ['01:30 PM', '03:00 PM', '04:30 PM'],
      },
      {
        'label': 'EVENING',
        'icon': Icons.nightlight_round,
        'slots': ['06:00 PM', '07:30 PM', '09:00 PM'],
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(_selectedDate!),
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B)),
                    ),
                    Text('Tap slots to enable/disable',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              if (enabledSlots.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() => _availability.remove(_dateKey(_selectedDate!)));
                  },
                  child: Text('Clear all',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500)),
                ),
              if (enabledSlots.length < _allSlots.length)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _availability[_dateKey(_selectedDate!)] =
                            Set<String>.from(_allSlots);
                      });
                    },
                    child: Text('All',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: primaryIndigo,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...sections.map((section) {
            final slots = section['slots'] as List<String>;
            final icon = section['icon'] as IconData;
            final label = section['label'] as String;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(label,
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: slots
                      .map((slot) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _slotChip(slot, enabledSlots.contains(slot)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _slotChip(String slot, bool enabled) {
    return GestureDetector(
      onTap: () => _toggleSlot(_selectedDate!, slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: enabled ? primaryIndigo : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? primaryIndigo : Colors.grey.shade200,
            width: enabled ? 0 : 1.5,
          ),
        ),
        child: Center(
          child: Text(slot,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_availability.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No availability set yet. Select dates on the calendar and enable time slots.',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: Colors.orange.shade700, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final sortedDates = _availability.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Availability Summary',
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B))),
          const SizedBox(height: 12),
          ...sortedDates.take(10).map((dateKey) {
            final dt = DateTime.parse(dateKey);
            final slots = _availability[dateKey]!.toList()..sort();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryIndigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        DateFormat('d').format(dt),
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryIndigo),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE, d MMM').format(dt),
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text('${slots.length} slots: ${slots.take(3).join(', ')}${slots.length > 3 ? '...' : ''}',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.shade300),
                    onPressed: () {
                      setState(() => _availability.remove(dateKey));
                      if (_selectedDate != null &&
                          _dateKey(_selectedDate!) == dateKey) {
                        _selectedDate = null;
                      }
                    },
                  ),
                ],
              ),
            );
          }),
          if (_availability.length > 10)
            Text('+ ${_availability.length - 10} more dates...',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveAvailability,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryIndigo,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('Save Availability',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
