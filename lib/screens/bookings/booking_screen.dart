import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final String? providerProfileUrl;
  final String? priceType;
  final int? minHours;
  final int? maxHours;

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
    this.providerProfileUrl,
    this.priceType,
    this.minHours,
    this.maxHours,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int step = 1;
  DateTime selectedDate = DateTime.now();
  String? selectedTime;
  bool isGettingLocation = false;
  bool _isLoadingAvailability = true;

  // Availability loaded from Firestore: "yyyy-MM-dd" → List<String>
  Map<String, List<String>> _serviceAvailability = {};

  List<String> get _slotsForSelectedDate {
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
    return _serviceAvailability[key] ?? [];
  }

  bool _hasAvailability(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    return (_serviceAvailability[key] ?? []).isNotEmpty;
  }

  // Price Logic
  double get basePriceValue => double.tryParse(widget.price.replaceAll('RM', '').split('/')[0]) ?? 85.0;
  final double platformRate = 0.15;
  Set<int> selectedAddOnIndices = {};
  
  late int duration;

  @override
  void initState() {
    super.initState();
    duration = widget.minHours ?? 1;
    _loadAvailability();
    _fetchSavedAddresses();
  }
  
  double get currentSubtotal {
    double total = basePriceValue;
    if (widget.priceType == 'per hour') {
      total = basePriceValue * duration;
    }
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
  double? latitude;
  double? longitude;
  String phone = '';
  String notes = '';
  String paymentMethod = 'card';

  List<Map<String, dynamic>> _savedAddresses = [];
  String? _selectedAddressId;

  final Color primaryGreen = const Color(0xFFFF6B00);
  final Color bgCream = Colors.white;

  Future<void> _fetchSavedAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .orderBy('isDefault', descending: true)
          .get();
      if (mounted) {
        setState(() {
          _savedAddresses = snapshot.docs.map((doc) => {
            ...doc.data(),
            'id': doc.id,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching saved addresses: $e");
    }
  }

  Future<void> _loadAvailability() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();
      if (doc.exists) {
        final rawMap =
            doc.data()?['availability'] as Map<String, dynamic>? ?? {};
        final parsed = <String, List<String>>{};
        rawMap.forEach((date, slots) {
          parsed[date] = List<String>.from(slots as List);
        });
        if (mounted) {
          setState(() {
            _serviceAvailability = parsed;
            // If provider set availability, reset default time
            selectedTime = null;
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
    final bool hasProviderAvailability = _serviceAvailability.isNotEmpty;
    final slots = _slotsForSelectedDate;
    final morningSlots = slots.where((s) => s.contains('AM')).toList()..sort();
    final afternoonSlots = slots.where((s) {
      if (!s.contains('PM')) return false;
      final h = int.tryParse(s.split(':')[0]) ?? 0;
      return h >= 1 && h < 6;
    }).toList()..sort();
    final eveningSlots = slots.where((s) {
      if (!s.contains('PM')) return false;
      final h = int.tryParse(s.split(':')[0]) ?? 0;
      return h >= 6;
    }).toList()..sort();

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
          child: _buildCalendar(hasProviderAvailability),
        ),
        const SizedBox(height: 48),
        if (_isLoadingAvailability)
          const Center(child: CircularProgressIndicator())
        else if (slots.isEmpty && hasProviderAvailability)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, color: Colors.orange.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No time slots available for this date. Please select another date.',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.orange.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (widget.priceType == 'per hour') ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking Duration', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('How many hours do you need?', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hours', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (duration > (widget.minHours ?? 1)) {
                            setState(() => duration--);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.remove, size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text('$duration', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          if (duration < (widget.maxHours ?? 8)) {
                            setState(() => duration++);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Times', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text('Select one slot', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 24),
          if (hasProviderAvailability) ...[
            _timeSection('MORNING', Icons.wb_sunny_outlined, ['08:00 AM', '09:30 AM', '11:00 AM'], availableSlots: morningSlots),
            const SizedBox(height: 12),
            _timeSection('AFTERNOON', Icons.sunny, ['01:30 PM', '03:00 PM', '04:30 PM'], availableSlots: afternoonSlots),
            const SizedBox(height: 12),
            _timeSection('EVENING', Icons.nightlight_round, ['06:00 PM', '07:30 PM', '09:00 PM'], availableSlots: eveningSlots),
          ] else ...[
            // Fallback: show default slots if provider hasn't set availability
            _timeSection('MORNING', Icons.wb_sunny_outlined, ['08:00 AM', '09:30 AM', '11:00 AM']),
            const SizedBox(height: 12),
            _timeSection('AFTERNOON', Icons.sunny, ['01:30 PM', '03:00 PM', '04:30 PM']),
            const SizedBox(height: 12),
            _timeSection('EVENING', Icons.nightlight_round, ['06:00 PM', '07:30 PM', '09:00 PM']),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCalendar([bool hasProviderAvailability = false]) {
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
      final hasSlots = hasProviderAvailability ? _hasAvailability(date) : true;
      final isUnavailable = hasProviderAvailability && !hasSlots && !isPast;
      gridItems.add(GestureDetector(
        onTap: (isPast || isUnavailable) ? null : () => setState(() {
          selectedDate = date;
          selectedTime = null; // Reset time when date changes
        }),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : (isToday ? primaryGreen.withValues(alpha: 0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(6)
          ),
          child: Center(child: Text('$d', style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isPast
                    ? Colors.grey.shade200
                    : isUnavailable
                        ? Colors.grey.shade300
                        : isToday
                            ? primaryGreen
                            : Colors.black87,
          ))),
        ),
      ));
    }
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, childAspectRatio: 1.4, children: gridItems);
  }

  Widget _timeSection(String title, IconData icon, List<String> allSlots, {List<String>? availableSlots}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: primaryGreen), const SizedBox(width: 8), Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5))]),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: allSlots.map((s) {
            bool isAvailable = availableSlots == null || availableSlots.contains(s);
            return _timeSlot(s, isAvailable: isAvailable);
          }).toList()
        ),
    ]);
  }

  Widget _timeSlot(String time, {bool isAvailable = true}) {
    bool isSelected = selectedTime == time;
    return GestureDetector(
      onTap: isAvailable ? () => setState(() => selectedTime = time) : null,
      child: Container(
        width: 100, height: 50,
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : (isAvailable ? Colors.white : Colors.grey.shade100), 
          borderRadius: BorderRadius.circular(8), 
          border: isSelected ? null : Border.all(color: Colors.black.withValues(alpha: isAvailable ? 0.1 : 0.05), width: 1.5),
          boxShadow: [
            if (!isSelected && isAvailable) BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Center(child: Text(time, style: GoogleFonts.outfit(
          fontSize: 14, 
          fontWeight: FontWeight.w600, 
          color: isSelected ? Colors.white : (isAvailable ? Colors.black87 : Colors.grey.shade400)
        ))),
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
      
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      try {
        if (kIsWeb) {
          final apiKey = 'AIzaSyAbuq1D2c5ZgL5jGjQSCp3tFWx2S7aBl60';
          final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
              final components = data['results'][0]['address_components'] as List;
              String unit = '';
              String route = '';
              String sublocal = '';
              String zip = '';
              String city = '';
              for (var c in components) {
                List types = c['types'];
                if (types.contains('street_number') || types.contains('premise')) unit = c['long_name'];
                if (types.contains('route')) route = c['long_name'];
                if (types.contains('sublocality')) sublocal = c['long_name'];
                if (types.contains('postal_code')) zip = c['long_name'];
                if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                  if (city.isEmpty) city = c['long_name'];
                }
              }
              setState(() {
                unitNoController.text = unit;
                streetNameController.text = route.isNotEmpty ? route : sublocal;
                postcodeController.text = zip;
                cityController.text = city;
              });
            } else {
              throw Exception("Web Reverse Geocoding API returned no results.");
            }
          } else {
            throw Exception("Web Reverse Geocoding HTTP Error ${response.statusCode}");
          }
        } else {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            debugPrint("📍 Placemark details: ${place.toJson()}");
            setState(() {
              unitNoController.text = place.subThoroughfare ?? '';
              String street = place.street ?? '';
              String thoroughfare = place.thoroughfare ?? '';
              String subLocality = place.subLocality ?? '';
              if (thoroughfare.isNotEmpty) {
                streetNameController.text = thoroughfare;
              } else if (street.isNotEmpty && !street.contains('+')) {
                streetNameController.text = street;
              } else if (subLocality.isNotEmpty) {
                streetNameController.text = subLocality;
              } else {
                streetNameController.text = place.name ?? '';
              }
              postcodeController.text = place.postalCode ?? '';
              cityController.text = place.locality ?? place.subAdministrativeArea ?? '';
            });
          }
        }
      } catch (e) {
        debugPrint("Reverse geocoding failed: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location found, but address details must be entered manually.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
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
        _buildSavedAddressesList(),
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

  Widget _buildSavedAddressesList() {
    if (_savedAddresses.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAVED ADDRESSES',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _savedAddresses.length,
            itemBuilder: (context, index) {
              final addr = _savedAddresses[index];
              final isSelected = _selectedAddressId == addr['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAddressId = addr['id'];
                    final addrStr = addr['address'] as String? ?? '';
                    final parts = addrStr.split(',').map((e) => e.trim()).toList();
                    unitNoController.text = parts.isNotEmpty ? parts[0] : '';
                    streetNameController.text = parts.length > 1 ? parts[1] : '';
                    postcodeController.text = parts.length > 2 ? parts[2] : '';
                    cityController.text = parts.length > 3 ? parts.sublist(3).join(', ') : '';
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  width: 180,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryGreen.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryGreen : Colors.grey.shade200,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            addr['isDefault'] == true ? Icons.home_rounded : Icons.location_on_outlined,
                            size: 14,
                            color: isSelected ? primaryGreen : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              addr['label'] ?? 'Address',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addr['address'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
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

  void _showBookingSummary() async {
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
    if (widget.priceType == 'per hour') {
      base = basePriceValue * duration;
    }
    double addOnsSum = 0;
    final list = addOns;
    for (var idx in selectedAddOnIndices) {
      final p = list[idx]['price'];
      addOnsSum += (p is String ? double.tryParse(p) : (p as num).toDouble()) ?? 0.0;
    }
    double platformFee = (base + addOnsSum) * platformRate;
    double finalTotal = base + addOnsSum + platformFee;

    // Manual Geocoding Fallback if they didn't use GPS button
    if (latitude == null || longitude == null) {
      final fullAddress = '$streetName, $postcode $city';
      if (kIsWeb) {
        try {
          final apiKey = 'AIzaSyAbuq1D2c5ZgL5jGjQSCp3tFWx2S7aBl60';
          final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(fullAddress)}&key=$apiKey');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
              final location = data['results'][0]['geometry']['location'];
              latitude = location['lat'];
              longitude = location['lng'];
            } else {
              debugPrint("Web Geocoding API returned no results: ${data['status']}");
            }
          } else {
            debugPrint("Web Geocoding API failed with status ${response.statusCode}");
          }
        } catch (e) {
          debugPrint("Web Geocoding API exception: $e");
        }
      } else {
        try {
          final locs = await locationFromAddress(fullAddress);
          if (locs.isNotEmpty) {
            latitude = locs.first.latitude;
            longitude = locs.first.longitude;
          }
        } catch (e) {
          debugPrint("Native Geocoding failed: $e");
        }
      }
    }

    if (!mounted) return;

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
              
              _summaryRow(widget.priceType == 'per hour' ? 'Service Price ($duration hrs)' : 'Service Price', 'RM ${base.toStringAsFixed(2)}'),
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
                          basePrice: base,
                          selectedAddOns: selectedAddOnIndices.map((idx) => addOns[idx]).toList(),
                          address: 'Unit $unitNo, $streetName, $postcode $city',
                          latitude: latitude,
                          longitude: longitude,
                          totalPrice: finalTotal,
                          serviceId: widget.serviceId,
                          providerProfileUrl: widget.providerProfileUrl,
                          durationHours: widget.priceType == 'per hour' ? duration : null,
                          priceType: widget.priceType,
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
