import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class LocationRangeScreen extends StatefulWidget {
  final LatLng initialLocation;
  final double initialRangeKm;
  
  const LocationRangeScreen({
    super.key, 
    required this.initialLocation,
    this.initialRangeKm = 10,
  });

  @override
  State<LocationRangeScreen> createState() => _LocationRangeScreenState();
}

class _LocationRangeScreenState extends State<LocationRangeScreen> {
  GoogleMapController? _mapController;
  late double _currentRangeKm;
  late LatLng _centerLocation;
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _currentRangeKm = widget.initialRangeKm;
    _centerLocation = widget.initialLocation;
    _updateCircle();
  }

  void _updateCircle() {
    setState(() {
      _circles = {
        Circle(
          circleId: const CircleId('range_circle'),
          center: _centerLocation,
          radius: _currentRangeKm * 1000, // Convert km to meters
          fillColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
          strokeColor: const Color(0xFFFF6B00),
          strokeWidth: 2,
        )
      };
    });
    
    // Animate camera to fit the circle exactly on screen
    if (_mapController != null) {
      // Calculate bounds for the circle
      // 1 degree of latitude is roughly 111km
      double latDelta = (_currentRangeKm / 111.0);
      // Rough approximation of 1 degree longitude at given latitude
      double lngDelta = (_currentRangeKm / (111.0 * _getDistanceScaleAdjustment(_centerLocation.latitude)));

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(_centerLocation.latitude - latDelta, _centerLocation.longitude - lngDelta),
        northeast: LatLng(_centerLocation.latitude + latDelta, _centerLocation.longitude + lngDelta),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0) // 50.0 is padding in pixels
      );
    }
  }

  // Adjust longitude scale based on latitude since longitudes converge at the poles
  double _getDistanceScaleAdjustment(double latitude) {
    return math.cos(latitude * math.pi / 180.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Location Range',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centerLocation,
              zoom: 12.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateCircle();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            circles: _circles,
            markers: {
              Marker(
                markerId: const MarkerId('center_point'),
                position: _centerLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              )
            },
          ),
          
          // Bottom Control Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distance Range',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentRangeKm.round()} km',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFFFF6B00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFFF6B00),
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: const Color(0xFFFF6B00),
                        overlayColor: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        trackHeight: 6,
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                        activeTickMarkColor: Colors.white,
                        inactiveTickMarkColor: const Color(0xFFFF6B00).withValues(alpha: 0.5),
                      ),
                      child: Slider(
                        value: _currentRangeKm,
                        min: 5,
                        max: 25,
                        divisions: 4, // 5, 10, 15, 20, 25
                        onChanged: (value) {
                          setState(() {
                            _currentRangeKm = value;
                          });
                          _updateCircle();
                        },
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('5km', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12)),
                          Text('25km', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _currentRangeKm);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Apply Range Filters',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Center My Location Button
          Positioned(
            bottom: 270,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: () async {
                try {
                  Position position = await Geolocator.getCurrentPosition();
                  setState(() {
                    _centerLocation = LatLng(position.latitude, position.longitude);
                    _updateCircle();
                  });
                } catch (e) {
                  // Handle Error gracefully
                }
              },
              child: const Icon(Icons.my_location, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
