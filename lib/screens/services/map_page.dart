import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 📍 KLCC Coordinates
  static const LatLng _klccLocation = LatLng(3.1579, 101.7115);


  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId("klcc_marker"),
      position: LatLng(3.1579, 101.7115),
      infoWindow: InfoWindow(title: "Kuala Lumpur Convention Center"),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Location"),
        backgroundColor: const Color(0xFFFF6B00),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _klccLocation,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          // Map Controller available if needed
        },
        markers: _markers,
        zoomControlsEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}
