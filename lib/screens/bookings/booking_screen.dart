import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'payment_page.dart';

class BookingPage extends StatefulWidget {
  final String providerName;
  final String serviceName;
  final String price;

  const BookingPage({
    super.key,
    required this.providerName,
    required this.serviceName,
    required this.price,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int step = 1;
  DateTime selectedDate = DateTime.now();
  String? selectedTime = "09:30 AM";

  // Price Logic
  double get basePriceValue => double.tryParse(widget.price.replaceAll('RM', '').split('/')[0]) ?? 85.0;
  final double serviceFeeValue = 45.0; 
  final double platformFeeValue = 5.0;
  Set<int> selectedAddOnIndices = {};
  
  final List<Map<String, dynamic>> addOns = [
    {'name': 'Kitchen Deep Cleaning', 'description': 'Oven, cabinets, and splash-back restoration.', 'price': 30.0},
    {'name': 'Aircond Cleaning', 'description': 'Standard filter and coil chemical service.', 'price': 120.0},
    {'name': 'Exterior Window Cleaning', 'description': 'Detailed polishing for glass surfaces.', 'price': 45.0},
  ];

  String get calculatedTotal {
    double total = basePriceValue + platformFeeValue;
    for (var index in selectedAddOnIndices) {
      total += addOns[index]['price'];
    }
    return 'RM${total.toStringAsFixed(0)}';
  }

  String address = '';
  String phone = '';
  String notes = '';
  String paymentMethod = 'card';

  final Color primaryGreen = const Color(0xFFFF6B00);
  final Color bgCream = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Book Service',
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StepIndicatorDelegate(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _buildStepIndicator(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: step == 1 
                        ? _buildScheduleStep() 
                        : (step == 2 ? _buildCustomiseStep() : _buildLocationStep()),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepCircle(1, 'SCHEDULE', active: step >= 1),
        _stepLine(active: step >= 2),
        _stepCircle(2, 'CUSTOMISE', active: step >= 2),
        _stepLine(active: step >= 3),
        _stepCircle(3, 'LOCATION', active: step >= 3),
      ],
    );
  }

  Widget _stepCircle(int n, String label, {required bool active}) {
    return InkWell(
      onTap: () => setState(() => step = n),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? primaryGreen : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$n',
                style: GoogleFonts.inter(
                  color: active ? Colors.white : Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: active ? primaryGreen : Colors.grey.shade400, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _stepLine({required bool active}) {
    return Container(width: 50, height: 1, margin: const EdgeInsets.only(left: 8, right: 8, bottom: 20), color: active ? primaryGreen : Colors.grey.shade300);
  }

  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Select Date',
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            Text(
              DateFormat('MMMM yyyy').format(selectedDate),
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: _buildCalendar(),
        ),
        const SizedBox(height: 48),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Times', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Select one slot', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 24),
        _timeSection('MORNING', Icons.wb_sunny_outlined, ['08:00 AM', '09:30 AM', '11:00 AM']),
        const SizedBox(height: 12),
        _timeSection('AFTERNOON', Icons.sunny, ['01:30 PM', '03:00 PM', '04:30 PM']),
        const SizedBox(height: 12),
        _timeSection('EVENING', Icons.nightlight_round, ['06:00 PM', '07:30 PM', '09:00 PM']),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);
    int blankDays = firstDayOfMonth.weekday - 1; 

    List<Widget> gridItems = [];
    for (var day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
      gridItems.add(Center(child: Text(day.substring(0, 3), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400))));
    }
    for (int i = 0; i < blankDays; i++) {
      gridItems.add(const SizedBox());
    }
    for (int d = 1; d <= lastDayOfMonth.day; d++) {
      final date = DateTime(selectedDate.year, selectedDate.month, d);
      final isPast = date.isBefore(today);
      final isToday = date.day == today.day && date.month == today.month && date.year == today.year;
      final isSelected = selectedDate.day == d && selectedDate.month == date.month;
      gridItems.add(GestureDetector(
        onTap: isPast ? null : () => setState(() => selectedDate = date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: isSelected ? primaryGreen : (isToday ? primaryGreen.withValues(alpha: 0.1) : Colors.transparent), borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text('$d', style: GoogleFonts.inter(fontSize: 14, fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : (isPast ? Colors.grey.shade200 : (isToday ? primaryGreen : Colors.black87))))),
        ),
      ));
    }
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, childAspectRatio: 1.4, children: gridItems);
  }

  Widget _timeSection(String title, IconData icon, List<String> slots) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: primaryGreen), const SizedBox(width: 8), Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.5))]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: slots.map((s) => _timeSlot(s)).toList()),
    ]);
  }

  Widget _timeSlot(String time) {
    bool isSelected = selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => selectedTime = time),
      child: Container(
        width: 100, height: 50,
        decoration: BoxDecoration(color: isSelected ? primaryGreen : Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Center(child: Text(time, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87))),
      ),
    );
  }

  Widget _buildCustomiseStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add-ons', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        const SizedBox(height: 24),
        ...List.generate(addOns.length, (index) {
          final item = addOns[index];
          final isSelected = selectedAddOnIndices.contains(index);
          return GestureDetector(
            onTap: () => setState(() => isSelected ? selectedAddOnIndices.remove(index) : selectedAddOnIndices.add(index)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade100, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['name'], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text(item['description'], style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        Text('+ RM${item['price'].toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                  ])),
                  const SizedBox(width: 16),
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: isSelected ? primaryGreen : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300)), child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
              ]),
            ),
          );
        }),
    ]);
  }

  String unitNo = '';
  String streetName = '';
  String entryInstructions = '';

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Your Address',
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 24),
        Text(
          'UNIT / HOUSE NO.',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (val) => setState(() => unitNo = val),
          decoration: InputDecoration(
            hintText: 'e.g. 4B',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 24),

        // Street Name
        Text(
          'STREET NAME',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (val) => setState(() => streetName = val),
          decoration: InputDecoration(
            hintText: 'e.g. Jalan Sultan Ismail',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 24),
        Text(
          'ENTRY INSTRUCTIONS',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (val) => setState(() => entryInstructions = val),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Gate code, side door, or parking info...',
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildFooter() {
    final bool isLastStep = step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          if (!isLastStep) ...[
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(step == 2 ? 'TOTAL PRICE' : 'SELECTED DATE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(step == 2 ? calculatedTotal : '${DateFormat('MMM dd').format(selectedDate)}, ${selectedTime ?? 'Not selected'}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen)),
              ]),
            ),
            const SizedBox(width: 16),
          ],
          
          if (isLastStep)
            Expanded(
              child: _mainActionButton(isLastStep),
            )
          else 
            SizedBox(
              width: 180,
              child: _mainActionButton(isLastStep),
            ),
        ],
      ),
    );
  }

  Widget _mainActionButton(bool isLastStep) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: () => step < 3 ? setState(() => step++) : _showBookingSummary(),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          elevation: 0,
        ),
        child: Text(step == 3 ? 'Confirm' : 'Continue', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showBookingSummary() {
    if (unitNo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your unit/house number')));
      return;
    }

    // Calculations
    double base = basePriceValue;
    double addOnsSum = 0;
    for (var idx in selectedAddOnIndices) {
      addOnsSum += addOns[idx]['price'];
    }
    double finalTotal = base + addOnsSum;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('Summary', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(height: 32),
              
              _summaryRow('Service Price', 'RM ${base.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              
              if (selectedAddOnIndices.isNotEmpty) ...[
                _summaryRow('Add-ons', 'RM ${addOnsSum.toStringAsFixed(2)}'),
                Container(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade100, width: 2))),
                  child: Column(
                    children: selectedAddOnIndices.map((idx) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(addOns[idx]['name'], style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                          Text('RM ${addOns[idx]['price'].toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              _summaryRow('Address', 'Unit $unitNo, $streetName'),
              
              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL AMOUNT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen, letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text('RM ${finalTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                    child: Text('SECURE PAY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: primaryGreen)),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _assuranceRow(Icons.shield_outlined, 'Protection Guarantee included.'),
                    const SizedBox(height: 12),
                    _assuranceRow(Icons.event_available_outlined, 'Free cancellation until 24h before.'),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close summary
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentPage(
                          providerName: widget.providerName,
                          serviceName: widget.serviceName,
                          selectedDate: selectedDate,
                          selectedTime: selectedTime ?? '',
                          basePrice: basePriceValue,
                          selectedAddOns: selectedAddOnIndices.map((idx) => addOns[idx]).toList(),
                          address: 'Unit $unitNo, $streetName',
                          totalPrice: finalTotal,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Continue to Payment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assuranceRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryGreen),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ],
    );
  }


}

class _StepIndicatorDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StepIndicatorDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent 
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))] 
            : null,
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => 95.0;
  @override
  double get minExtent => 95.0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
