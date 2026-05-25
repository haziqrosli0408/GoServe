import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/single_chat_screen.dart';
import 'help_center_screen.dart';
import 'service_completed_screen.dart';
import 'cancel_booking_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TrackingScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;
  const TrackingScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
  }

  
  // Default center if no coordinates found
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Provider phone number not available')),
        );
      }
      return;
    }
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).snapshots(),
        builder: (context, snapshot) {
          LatLng providerLatLng = _defaultCenter;
          String arrivalTime = '15 mins';
          String distanceText = '2.4 miles';
          Map<String, dynamic>? data;
          String currentStatus = 'Confirmed';

          if (snapshot.hasData && snapshot.data!.exists) {
            data = snapshot.data!.data() as Map<String, dynamic>;
            currentStatus = data['status'] ?? 'Pending';

            // Handle Profile Picture Marker (Safely outside build)

            // Get customer destination coordinates
            double destLat = (widget.bookingData['latitude'] is double) 
                ? widget.bookingData['latitude'] 
                : double.tryParse(widget.bookingData['latitude'].toString()) ?? 0.0;
            double destLng = (widget.bookingData['longitude'] is double) 
                ? widget.bookingData['longitude'] 
                : double.tryParse(widget.bookingData['longitude'].toString()) ?? 0.0;
            LatLng destLatLng = (destLat != 0 && destLng != 0) ? LatLng(destLat, destLng) : _defaultCenter;

            // Robust location extraction for provider
            final dynamic provLocRaw = data['providerLocation'];
            if (provLocRaw is GeoPoint) {
              providerLatLng = LatLng(provLocRaw.latitude, provLocRaw.longitude);
            } else if (data['providerLatitude'] != null && data['providerLongitude'] != null) {
              providerLatLng = LatLng(
                (data['providerLatitude'] as num).toDouble(),
                (data['providerLongitude'] as num).toDouble(),
              );
            } else if (data['latitude'] != null && data['longitude'] != null && currentStatus != 'Pending') {
              // Fallback for manual testing if using root lat/lng (only if not Pending)
              providerLatLng = LatLng(
                (data['latitude'] as num).toDouble(),
                (data['longitude'] as num).toDouble(),
              );
            }

            double distance = 0;
            if (data['providerLocation'] != null || data['latitude'] != null) {
              if (destLat != 0 && destLng != 0) {
                // Simplified distance calculation (Haversine-like)
                const double R = 6371; // Earth's radius in km
                double dLat = (destLat - providerLatLng.latitude) * (math.pi / 180);
                double dLon = (destLng - providerLatLng.longitude) * (math.pi / 180);
                double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
                    math.cos(providerLatLng.latitude * (math.pi / 180)) * 
                    math.cos(destLat * (math.pi / 180)) * 
                    math.sin(dLon / 2) * math.sin(dLon / 2);
                double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
                distance = R * c;

                distanceText = "${distance.toStringAsFixed(1)} km";
                // Estimate arrival time (assuming 30km/h average in city -> 2 mins per km)
                int mins = (distance * 2).ceil();
                if (mins < 1) mins = 1;
                arrivalTime = "$mins mins";
              }
            }

            _markers.clear();
            
            // 1. Destination Marker (Customer's address)
            if (destLat != 0 && destLng != 0) {
              _markers.add(
                Marker(
                  markerId: const MarkerId('destination'),
                  position: destLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: InfoWindow(title: 'Service Location', snippet: widget.bookingData['address'] ?? ''),
                ),
              );
            }

            // 2. Provider Marker - REMOVED for stability as requested

            // 3. Polyline (Path)
            if (currentStatus == 'On the way' && provLocRaw != null && destLat != 0) {
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: [providerLatLng, destLatLng],
                  color: const Color(0xFFFF6B00),
                  width: 4,
                  patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                ),
              );
            }

            // 🔹 Dynamic Camera & Navigation Logic (Safe Side Effects)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              // 1. Navigation to completion screen
              if (currentStatus == 'Completed') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceCompletedScreen(bookingData: data!),
                  ),
                );
                return;
              }

              // 2. Map Camera Updates
              if (_mapController != null) {
                // Check if distance is realistic (e.g., < 500km) before trying to fit both
                if (currentStatus == 'On the way' && distance < 500) {
                  LatLngBounds bounds = LatLngBounds(
                    southwest: LatLng(
                      math.min(providerLatLng.latitude, destLat),
                      math.min(providerLatLng.longitude, destLng),
                    ),
                    northeast: LatLng(
                      math.max(providerLatLng.latitude, destLat),
                      math.max(providerLatLng.longitude, destLng),
                    ),
                  );
                  _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
                } else {
                  // If too far or not on the way, just focus on destination
                  _mapController!.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 15));
                }
              }
            });
            
            // If the provider location exists but no controller yet, update providerLatLng for initial camera
            if (provLocRaw == null && destLat != 0) {
              providerLatLng = destLatLng;
            }
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Track Service',
                    style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Text(
                    'Order ID: ${data?['orderId'] ?? widget.bookingData['orderId'] ?? 'GS-00000'}',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              actions: [
                if (currentStatus == 'Confirmed')
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: const Icon(Icons.more_vert, color: Color(0xFF1E293B)),
                    ),
                    onSelected: (value) {
                      if (value == 'cancel') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CancelBookingSheet(
                            bookingId: widget.bookingId,
                            bookingData: data!,
                          ),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 8),
                            Text('Cancel Booking', style: GoogleFonts.outfit(color: Colors.red.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, color: Color(0xFFFF6B00)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HelpCenterScreen(bookingData: widget.bookingData),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Horizontal Status
                  _buildHorizontalStatus(currentStatus),
                  
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 2. Map
                  Container(
                    height: 250,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: (widget.bookingData['latitude'] != null) 
                            ? LatLng(
                                double.tryParse(widget.bookingData['latitude'].toString()) ?? _defaultCenter.latitude,
                                double.tryParse(widget.bookingData['longitude'].toString()) ?? _defaultCenter.longitude
                              ) 
                            : providerLatLng, 
                        zoom: 15
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      circles: {
                        if (['On the way', 'Arrived', 'In progress'].contains(currentStatus))
                          Circle(
                            circleId: const CircleId('provider_pulse'),
                            center: providerLatLng,
                            radius: 30, // meters
                            fillColor: const Color(0xFF2196F3).withValues(alpha: 0.3),
                            strokeColor: const Color(0xFF1976D2),
                            strokeWidth: 2,
                          ),
                      },
                      onMapCreated: (controller) => _mapController = controller,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  ),

                  // Floating Stats if on the way
                  if (currentStatus == 'On the way')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFloatingStats(arrivalTime, distanceText),
                    ),

                  const SizedBox(height: 12),
                  
                  // 3. Provider Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildProviderCard(data),
                  ),

                  const SizedBox(height: 16),

                  // 4. Address Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAddressSection(data ?? widget.bookingData),
                  ),

                  const SizedBox(height: 16),

                  // 5. Order Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildOrderDetailSection(data ?? widget.bookingData),
                  ),
                  
                  const SizedBox(height: 120), // Padding for bottom actions
                ],
              ),
            ),
            bottomSheet: _buildBottomActions(currentStatus),
          );
        }
      ),
    );
  }

  Widget _buildFloatingStats(String arrivalTime, String distanceText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(Icons.access_time_filled, 'ESTIMATED ARRIVAL', arrivalTime),
            VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
            _statItem(null, 'DISTANCE', distanceText),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData? icon, String label, String value) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF0E6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF6B00)),
          ),
          const SizedBox(width: 10),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 0.5),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderCard(Map<String, dynamic>? data) {
    String name = data?['providerName'] ?? widget.bookingData['providerName'] ?? 'Provider';
    String photoUrl = data?['providerProfileUrl'] ?? data?['profileUrl'] ?? '';
    String providerId = data?['providerId'] ?? widget.bookingData['providerId'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('providers').doc(providerId).get(),
        builder: (context, snapshot) {
          String rating = '0.0';
          String reviews = '0';
          String? phone;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final pData = snapshot.data!.data() as Map<String, dynamic>;
            rating = (pData['rating'] ?? 0.0).toStringAsFixed(1);
            reviews = (pData['reviews'] ?? 0).toString();
            phone = pData['phone'];
          }

          return Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty 
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 14, fontWeight: FontWeight.w600)) 
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E212C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($reviews reviews)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _makeCall(phone ?? data?['providerPhone'] ?? widget.bookingData['providerPhone'] ?? '011-23456789'),
                child: _actionIcon(Icons.phone_rounded),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SingleChatScreen(
                        provider: {
                          'providerId': providerId,
                          'providerName': name,
                          'providerProfileUrl': photoUrl,
                        },
                      ),
                    ),
                  );
                },
                child: _actionIcon(Icons.chat_bubble_rounded),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _actionIcon(IconData icon, {Color? color}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color ?? const Color(0xFFFF6B00), size: 18),
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> data) {
    String address = data['address'] ?? widget.bookingData['address'] ?? 'No address provided';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Address',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFFF6B00), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailSection(Map<String, dynamic> data) {
    String serviceName = data['serviceName'] ?? 'Service';
    double totalPaid = (data['totalPrice'] is num) 
        ? (data['totalPrice'] as num).toDouble() 
        : (double.tryParse(data['totalPrice']?.toString().replaceAll('RM', '').trim() ?? '0') ?? 0.0);
    
    double basePrice = (data['basePrice'] is num) 
        ? (data['basePrice'] as num).toDouble() 
        : totalPaid; // Fallback for legacy bookings

    List<dynamic> addOns = data['selectedAddOns'] ?? [];
    
    // If we have add-ons but basePrice is total, recalculate basePrice for display
    if (addOns.isNotEmpty && basePrice == totalPaid) {
      double addOnsTotal = 0;
      for (var addon in addOns) {
        final val = addon['price'];
        addOnsTotal += (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
      }
      basePrice = totalPaid - addOnsTotal;
    }

    double chargeFee = (data['chargeFee'] is num) 
        ? (data['chargeFee'] as num).toDouble() 
        : (totalPaid - basePrice - addOns.fold(0.0, (t, a) => t + (zval(a['price']))));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['status'] == 'Awaiting Confirmation' && data['proofImageUrl'] != null) ...[
            Text(
              'Work Proof',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F212C),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                data['proofImageUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 24),
          ],
          Text(
            'Order Detail',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                serviceName,
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              Text(
                'RM ${basePrice.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
              ),
            ],
          ),
          if (addOns.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            ...addOns.map((addon) {
              final a = Map<String, dynamic>.from(addon);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      a['name'] ?? 'Add-on',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
                    ),
                    Text(
                      'RM ${(double.tryParse(a['price']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Charge Fee (15%)',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
              ),
              Text(
                'RM ${chargeFee.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
              ),
              Text(
                'RM ${totalPaid.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B00)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double zval(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '0') ?? 0.0;
  }

  Widget _buildHorizontalStatus(String currentStatus) {
    List<String> statuses = ['On the way', 'Arrived', 'In progress', 'Complete'];
    // Map currentStatus to index
    int currentIndex = -1;
    if (currentStatus == 'On the way') {
      currentIndex = 0;
    } else if (currentStatus == 'Arrived') {
      currentIndex = 1;
    } else if (currentStatus == 'In progress' || currentStatus == 'Awaiting Confirmation') {
      currentIndex = 2;
    } else if (currentStatus == 'Completed') {
      currentIndex = 3;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(statuses.length, (index) {
          bool isCompleted = index < currentIndex;
          bool isActive = index == currentIndex;
          bool isLast = index == statuses.length - 1;

          return Expanded(
            flex: isLast ? 0 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Circle & Label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFFFF6B00) : (isActive ? Colors.white : Colors.grey.shade100),
                        shape: BoxShape.circle,
                        border: isActive ? Border.all(color: const Color(0xFFFF6B00), width: 6) : (isCompleted ? null : Border.all(color: Colors.grey.shade200)),
                      ),
                      child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statuses[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? const Color(0xFFFF6B00) : (isCompleted ? const Color(0xFF1F212C) : Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
                // Connecting Line
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 11), // Center line with 24px circle
                      child: AnimatedStatusLine(
                        isCompleted: isCompleted,
                        isActive: isActive,
                        isHorizontal: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }


  Widget _buildBottomActions(String currentStatus) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () async {
            // 🔹 UPDATE STATUS IN FIRESTORE TO COMPLETED
            try {
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(widget.bookingId)
                  .update({'status': 'Completed'});
              
              if (!mounted) return;
              // 🔹 NAVIGATE TO SUCCESS SPLASH → THEN RATING
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceCompletedScreen(bookingData: widget.bookingData),
                ),
              );
            } catch (e) {
              debugPrint('Error completing booking: $e');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            currentStatus == 'Awaiting Confirmation' ? 'Approve & Complete' : 'Service Completed', 
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)
          ),
        ),
      ),
    );
  }
}

class AnimatedStatusLine extends StatefulWidget {
  final bool isCompleted;
  final bool isActive;
  final bool isHorizontal;
  const AnimatedStatusLine({super.key, required this.isCompleted, required this.isActive, this.isHorizontal = false});

  @override
  State<AnimatedStatusLine> createState() => _AnimatedStatusLineState();
}

class _AnimatedStatusLineState extends State<AnimatedStatusLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompleted) {
      return Container(
        width: widget.isHorizontal ? double.infinity : 2, 
        height: widget.isHorizontal ? 2 : double.infinity,
        color: const Color(0xFFFF6B00)
      );
    }
    
    if (!widget.isActive) {
      return Container(
        width: widget.isHorizontal ? double.infinity : 2, 
        height: widget.isHorizontal ? 2 : double.infinity,
        color: Colors.grey.shade200
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: widget.isHorizontal ? const Size(double.infinity, 2) : const Size(2, double.infinity),
          painter: _LinePainter(_controller.value, isHorizontal: widget.isHorizontal),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  final double progress;
  final bool isHorizontal;
  _LinePainter(this.progress, {this.isHorizontal = false});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background line (grey)
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    if (isHorizontal) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), bgPaint);
    } else {
      canvas.drawLine(Offset(0, 0), Offset(0, size.height), bgPaint);
    }

    // 2. Growing orange bar (Filling effect)
    final orangePaint = Paint()
      ..color = const Color(0xFFFF6B00)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isHorizontal) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width * progress, size.height / 2), orangePaint);
    } else {
      canvas.drawLine(Offset(0, 0), Offset(0, size.height * progress), orangePaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => oldDelegate.progress != progress;
}
