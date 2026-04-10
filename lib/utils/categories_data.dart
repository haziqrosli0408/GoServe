import 'package:flutter/material.dart';

class AppCategories {
  static const List<Map<String, dynamic>> allCategories = [
    {
      'name': 'Home Services',
      'icon': Icons.home_repair_service_rounded, // Use IconData as fallback
      'assetPath': 'assets/icons/home.png', // Placeholder for your own icon
      'isAsset': true, // SET TO true WHEN YOU HAVE THE IMAGE IN ASSETS
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Electrical & Wiring',
      'icon': Icons.electrical_services_rounded,
      'assetPath': 'assets/icons/electrical.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Automotive',
      'icon': Icons.directions_car_rounded,
      'assetPath': 'assets/icons/automotive.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Moving',
      'icon': Icons.local_shipping_rounded,
      'assetPath': 'assets/icons/moving.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Health',
      'icon': Icons.fitness_center_rounded,
      'assetPath': 'assets/icons/health.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Pet Services',
      'icon': Icons.pets_rounded,
      'assetPath': 'assets/icons/pets.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Safety',
      'icon': Icons.security_rounded,
      'assetPath': 'assets/icons/safety.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Event',
      'icon': Icons.celebration_rounded,
      'assetPath': 'assets/icons/event.png',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
  ];

  static const Map<String, List<Map<String, dynamic>>> subcategoryMap = {
    'Home Services': [
      {'name': 'Cleaning', 'icon': Icons.cleaning_services_outlined},
      {'name': 'Repairing', 'icon': Icons.construction_outlined},
      {'name': 'Painting', 'icon': Icons.format_paint_outlined},
      {'name': 'Plumbing', 'icon': Icons.plumbing_outlined},
    ],
  };

  static List<Map<String, dynamic>> getHomeCategories() {
    return allCategories;
  }
}
