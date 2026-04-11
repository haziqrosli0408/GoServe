import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'payment_page.dart';

class BookingPage extends StatefulWidget {
  final String providerName;
  final String serviceName;
  final String serviceImage;
  final String category;
  final String price;
  final String? providerId;
  final List<dynamic>? addOns;
  final String serviceId;

  const BookingPage({
    super.key,
    required this.providerName,
    required this.serviceName,
    required this.serviceImage,
    required this.category,
    required this.price,
    this.providerId,
    this.addOns,
    required this.serviceId,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int step = 1;
  DateTime selectedDate = DateTime.now();
  String? selectedTime = "09:30 AM";
  bool isGettingLocation = false;

  // Price Logic
  double get basePriceValue => double.tryParse(widget.price.replaceAll('RM', '').split('/')[0]) ?? 85.0;
  final double platformRate = 0.15;
  Set<int> selectedAddOnIndices = {};
  
  double get currentSubtotal {
    double total = basePriceValue;
    final list = addOns;
    for (var index in selectedAddOnIndices) {
      final p = list[index]['price'];
      total += (p is String ? double.tryParse(p) : (p as num).toDouble()) ?? 0.0;
    }
    return total;
  }

  double get platformFeeValue => currentSubtotal * platformRate;
  
  List<Map<String, dynamic>> get addOns {
    if (widget.addOns == null) return [];
    return widget.addOns!.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String get calculatedTotal {
    return 'RM${(currentSubtotal + platformFeeValue).toStringAsFixed(0)}';
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
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4), // Added 12px top padding
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              step == 1 ? Icons.close : Icons.arrow_back,
                              color: Colors.black,
                              size: 28,
                            ),
                            onPressed: () {
                              if (step > 1) {
                                setState(() => step--);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          const Expanded(
                            child: SizedBox.shrink(),
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildStepIndicator(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
    String title;
    switch (step) {
      case 1:
        title = 'Schedule your booking';
        break;
      case 2:
        title = 'Customise your service';
        break;
      case 3:
        title = 'Set your location';
        break;
      default:
        title = 'Booking details';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, // Centered to move content up
        children: [
          Text(
            'step $step of 3',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryGreen,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width: (MediaQuery.of(context).size.width - 48) * (step / 3),
                decoration: BoxDecoration(
                  color: primaryGreen, // Orange Color(0xFFFF6B00)
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
            Text(
              DateFormat('MMMM yyyy').format(selectedDate),
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
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
            Text('Available Times', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Select one slot', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
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
      gridItems.add(Center(child: Text(day.substring(0, 3), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400))));
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
          child: Center(child: Text('$d', style: GoogleFonts.outfit(fontSize: 14, fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w500, color: isSelected ? Colors.white : (isPast ? Colors.grey.shade200 : (isToday ? primaryGreen : Colors.black87))))),
        ),
      ));
    }
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, childAspectRatio: 1.4, children: gridItems);
  }

  Widget _timeSection(String title, IconData icon, List<String> slots) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: primaryGreen), const SizedBox(width: 8), Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5))]),
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
        child: Center(child: Text(time, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87))),
      ),
    );
  }

  Widget _buildCustomiseStep() {
    if (addOns.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add-ons', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(Icons.extension_off_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No add-ons available for this service',
                  style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click continue to set your location',
                  style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add-ons', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 24),
        ...List.generate(addOns.length, (index) {
          final item = addOns[index];
          final isSelected = selectedAddOnIndices.contains(index);
          return GestureDetector(
            onTap: () => setState(() => isSelected ? selectedAddOnIndices.remove(index) : selectedAddOnIndices.add(index)),
            child: Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade100, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(item['name'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(item['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), height: 1.2)),
                        const SizedBox(height: 8),
                        Text('+ RM${(item['price'] is String ? double.tryParse(item['price']) : (item['price'] as num).toDouble())?.toStringAsFixed(0) ?? '0'}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: primaryGreen)),
                  ])),
                  const SizedBox(width: 16),
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: isSelected ? primaryGreen : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300)), child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
              ]),
            ),
          );
        }),
    ]);
  }

  final TextEditingController unitNoController = TextEditingController();
  final TextEditingController streetNameController = TextEditingController();
  final TextEditingController postcodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController entryInstructionsController = TextEditingController();

  @override
  void dispose() {
    unitNoController.dispose();
    streetNameController.dispose();
    postcodeController.dispose();
    cityController.dispose();
    entryInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }

      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          unitNoController.text = place.subThoroughfare ?? '';
          streetNameController.text = place.thoroughfare ?? place.name ?? '';
          postcodeController.text = place.postalCode ?? '';
          cityController.text = place.locality ?? place.subAdministrativeArea ?? '';
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isGettingLocation = false);
    }
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Your Address',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        
        // 🔹 USE CURRENT LOCATION BUTTON
        GestureDetector(
          onTap: isGettingLocation ? null : _getCurrentLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isGettingLocation 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  isGettingLocation ? 'GETTING LOCATION...' : 'Use current location',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.5),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        Text(
          'UNIT / HOUSE NO.',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: unitNoController,
          decoration: InputDecoration(
            hintText: 'e.g. 4B',
            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 24),

        // Street Name
        Text(
          'STREET NAME',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: streetNameController,
          decoration: InputDecoration(
            hintText: 'e.g. Jalan Sultan Ismail',
            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 24),

        // Postcode & City
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POSTCODE',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: postcodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 50450',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CITY',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cityController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Kuala Lumpur',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'ENTRY INSTRUCTIONS',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: entryInstructionsController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Gate code, side door, or parking info...',
            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
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
                  Text(step == 2 ? 'SUBTOTAL' : 'SELECTED DATE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(step == 2 ? 'RM${currentSubtotal.toStringAsFixed(0)}' : '${DateFormat('MMM dd').format(selectedDate)}, ${selectedTime ?? 'Not selected'}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: primaryGreen)),
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
        child: Text(step == 3 ? 'Confirm' : 'Continue', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showBookingSummary() {
    final unitNo = unitNoController.text;
    final streetName = streetNameController.text;
    final postcode = postcodeController.text;
    final city = cityController.text;

    if (unitNo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your unit/house number')));
      return;
    }

    // Calculations
    double base = basePriceValue;
    double addOnsSum = 0;
    final list = addOns;
    for (var idx in selectedAddOnIndices) {
      final p = list[idx]['price'];
      addOnsSum += (p is String ? double.tryParse(p) : (p as num).toDouble()) ?? 0.0;
    }
    double platformFee = (base + addOnsSum) * platformRate;
    double finalTotal = base + addOnsSum + platformFee;

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
              Text('Summary', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              const SizedBox(height: 32),
              
              _summaryRow('Address', 'Unit $unitNo, $streetName, $postcode $city'),
              const SizedBox(height: 32),
              const Divider(height: 1),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(addOns[idx]['name'], style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              'RM ${((addOns[idx]['price'] is String ? double.tryParse(addOns[idx]['price']) : (addOns[idx]['price'] as num).toDouble()) ?? 0.0).toStringAsFixed(2)}', 
                              textAlign: TextAlign.right,
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              _summaryRow('Charge Fee (15%)', 'RM ${platformFee.toStringAsFixed(2)}'),
              
              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL AMOUNT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: primaryGreen, letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text('RM ${finalTotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                    child: Text('SECURE PAY', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: primaryGreen)),
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
                          providerId: widget.providerId ?? '',
                          serviceName: widget.serviceName,
                          serviceImage: widget.serviceImage,
                          category: widget.category,
                          selectedDate: selectedDate,
                          selectedTime: selectedTime ?? '',
                          basePrice: basePriceValue,
                          selectedAddOns: selectedAddOnIndices.map((idx) => addOns[idx]).toList(),
                          address: 'Unit $unitNo, $streetName, $postcode $city',
                          totalPrice: finalTotal,
                          serviceId: widget.serviceId,
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
                      Text('Continue to Payment', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
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
        Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(width: 24),
        Expanded(
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
        ),
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
  double get maxExtent => 95.0; // Increased to move down
  @override
  double get minExtent => 95.0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
