import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/single_chat_screen.dart';
import 'help_center_screen.dart';
import 'service_completed_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

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
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final currentStatus = data['status'] ?? 'Pending';

            // 🔹 AUTO-NAVIGATE ONLY IF FINALIZED BY CUSTOMER or if it really is Completed
            if (currentStatus == 'Completed') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceCompletedScreen(bookingData: data),
                  ),
                );
              });
            }
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
                double distance = R * c;

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

            // 2. Provider Marker (Only if status is appropriate)
            if (['On the way', 'Arrived', 'In progress'].contains(currentStatus)) {
              _markers.add(
                Marker(
                  markerId: const MarkerId('provider'),
                  position: providerLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan), // Using Cyan for the 'vehicle'
                  infoWindow: InfoWindow(title: widget.bookingData['providerName'] ?? 'Provider'),
                  rotation: data['providerHeading']?.toDouble() ?? 0.0,
                ),
              );
            }

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

            // 🔹 Dynamic Camera Logic:
            if (_mapController != null) {
              if (currentStatus == 'On the way') {
                // Focus on both provider and destination when moving
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
                _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
              } else {
                // Default: Focus only on the customer destination
                _mapController!.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 16));
              }
            }
            
            // If the provider location exists but no controller yet, update providerLatLng for initial camera
            if (provLocRaw == null && destLat != 0) {
              providerLatLng = destLatLng;
            }
          }

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 4,
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
                      onMapCreated: (controller) => _mapController = controller,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: Colors.white,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 95, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildServiceStatus(currentStatus),
                            const SizedBox(height: 24),
                            _buildOrderDetailSection(data ?? widget.bookingData),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HelpCenterScreen(bookingData: widget.bookingData),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.help_outline_rounded, color: Color(0xFFFF6B00), size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (currentStatus == 'On the way')
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.31,
                  left: 20,
                  right: 20,
                  child: _buildFloatingStats(arrivalTime, distanceText),
                ),

              Positioned(
                top: MediaQuery.of(context).size.height * 0.38,
                left: 20,
                right: 20,
                child: _buildProviderCard(data),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomActions(currentStatus),
              ),
            ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty 
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 18, fontWeight: FontWeight.w600)) 
                  : null,
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80), // Vibrant Green
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E212C),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(128 reviews)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('providers').doc(providerId).get(),
            builder: (context, snapshot) {
              String? phone;
              if (snapshot.hasData && snapshot.data!.exists) {
                final pData = snapshot.data!.data() as Map<String, dynamic>?;
                phone = pData?['phone'];
              }
              return GestureDetector(
                onTap: () => _makeCall(phone ?? data?['providerPhone'] ?? widget.bookingData['providerPhone'] ?? '011-23456789'),
                child: _actionIcon(Icons.phone_rounded),
              );
            }
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
      ),
    );
  }

  Widget _actionIcon(IconData icon, {Color? color}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color ?? const Color(0xFFFF6B00), size: 20),
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
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                serviceName,
                style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF64748B)),
              ),
              Text(
                'RM ${basePrice.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
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
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
              ),
              Text(
                'RM ${totalPaid.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B00)),
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

  Widget _buildServiceStatus(String currentStatus) {
    // Phase logic
    bool bookingConfirmed = currentStatus != 'Pending';
    bool onTheWay = ['On the way', 'Arrived', 'In progress', 'Completed'].contains(currentStatus);
    bool arrived = ['Arrived', 'In progress', 'Completed'].contains(currentStatus);
    bool inProgress = ['In progress', 'Completed'].contains(currentStatus);
    bool completed = currentStatus == 'Completed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Status',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 24),
          _statusTimelineItem(
            'Booking Confirmed', 
            bookingConfirmed ? 'Your pro is confirmed' : 'Waiting for provider...', 
            currentStatus == 'Confirmed' ? 'Happening now' : '', 
            isCompleted: bookingConfirmed, 
            isActive: currentStatus == 'Pending',
            isLast: false,
          ),
          _statusTimelineItem(
            'Professional on the way', 
            'Pro is driving to your location', 
            currentStatus == 'On the way' ? 'Happening now' : '', 
            isCompleted: onTheWay && currentStatus != 'On the way',
            isActive: currentStatus == 'On the way', 
            isLast: false,
          ),
          _statusTimelineItem(
            'Arrived', 
            'Pro has arrived at your location', 
            currentStatus == 'Arrived' ? 'Happening now' : '', 
            isCompleted: arrived && currentStatus != 'Arrived',
            isActive: currentStatus == 'Arrived',
            isLast: false,
          ),
          _statusTimelineItem(
            'Work in progress', 
            'The magic is happening!', 
            currentStatus == 'In progress' ? 'Happening now' : '', 
            isCompleted: inProgress && currentStatus != 'In progress',
            isActive: currentStatus == 'In progress',
            isLast: false,
          ),
          _statusTimelineItem(
            'Completed', 
            'Service finished', 
            currentStatus == 'Completed' ? 'Done' : '', 
            isCompleted: completed,
            isActive: false, 
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _statusTimelineItem(String title, String subtitle, String time, {bool isCompleted = false, bool isActive = false, bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFFF6B00) : (isActive ? Colors.white : Colors.grey.shade200),
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: const Color(0xFFFF6B00), width: 6) : null,
                ),
                child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFFFF6B00) : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15, 
                      fontWeight: FontWeight.w600, 
                      color: isActive ? const Color(0xFFFF6B00) : (isCompleted ? const Color(0xFF1F212C) : Colors.grey.shade400)
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(fontSize: 13, color: isCompleted || isActive ? Colors.grey.shade600 : Colors.grey.shade300),
                    ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 11, 
                          fontWeight: FontWeight.w600, 
                          color: isActive ? Colors.deepOrange.shade800 : Colors.grey.shade400
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(String currentStatus) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
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
