import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  String _address = "Fetching address...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    if (widget.initialLocation != null) {
      setState(() {
        _pickedLocation = widget.initialLocation;
        _isLoading = false;
      });
      _getAddress(_pickedLocation!);
    } else {
      try {
        Position position = await _determinePosition();
        setState(() {
          _pickedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _getAddress(_pickedLocation!);
      } catch (e) {
        setState(() {
          _pickedLocation = const LatLng(3.1390, 101.6869); // Kuala Lumpur
          _isLoading = false;
        });
        _getAddress(_pickedLocation!);
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getAddress(LatLng location) async {
    if (kIsWeb) {
      // 🌐 DIRECT BROWSER GEOCoding (CORS-Safe)
      try {
        final geocoder = js.JsObject(js.context['google']['maps']['Geocoder']);
        final request = js.JsObject.jsify({
          'location': {'lat': location.latitude, 'lng': location.longitude}
        });

        geocoder.callMethod('geocode', [
          request,
          js.allowInterop((results, status) {
            if (status == 'OK' && results != null && results.length > 0) {
              setState(() {
                _address = results[0]['formatted_address'];
              });
            } else {
              setState(() {
                _address = "Google Error: $status";
              });
            }
          })
        ]);
      } catch (e) {
        setState(() {
          _address = "Bridge Error: ${e.toString()}";
        });
      }
      return;
    }

    // 📱 MOBILE VERSION
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address =
          "${place.street != null && place.street!.isNotEmpty ? '${place.street}, ' : ''}${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}"
              .replaceAll(RegExp(r'^, |, $'), '');
        });
      }
    } catch (e) {
      setState(() {
        _address = "Address not found";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pin Your Location',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation!,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              setState(() {
                _pickedLocation = position.target;
              });
            },
            onCameraIdle: () {
              _getAddress(_pickedLocation!);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: Icon(
                Icons.location_pin,
                size: 50,
                color: Color(0xFFFF6B00),
              ),
            ),
          ),
          // Bottom Address Bar
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _address,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'address': _address,
                            'location': _pickedLocation,
                          });
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
                          'Confirm Location',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // My Location Button
          Positioned(
            bottom: 220,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                Position position = await _determinePosition();
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(
                      LatLng(position.latitude, position.longitude)),
                );
              },
              child: const Icon(Icons.my_location, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
