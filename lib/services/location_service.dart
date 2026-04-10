import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;

  /// Request location permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Start tracking and updating Firestore for a specific booking
  Future<void> startTracking(String bookingId) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    // Stop previous tracking if any
    await stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
          'providerLocation': GeoPoint(position.latitude, position.longitude),
          'providerHeading': position.heading,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      },
      onError: (e) => debugPrint('Error in location stream: $e'),
    );
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Get current distance and ETA between two points (Simple calculation)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
