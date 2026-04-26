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
    {
      'name': 'Others',
      'icon': Icons.more_horiz_rounded,
      'assetPath': 'assets/icons/other.webp',
      'isAsset': true,
      'color': Color(0xFFFFF7ED),
      'iconColor': Color(0xFFFF6B00),
    },
  ];

  static const Map<String, List<Map<String, dynamic>>> subcategoryMap = {
    'Home Services': [
      {'name': 'House Cleaning', 'icon': Icons.cleaning_services_rounded},
      {'name': 'Move in / Move out cleaning', 'icon': Icons.cleaning_services_rounded},
      {'name': 'Plumbing', 'icon': Icons.plumbing_rounded},
      {'name': 'Aircond Service', 'icon': Icons.ac_unit_rounded},
      {'name': 'Pest control', 'icon': Icons.bug_report_rounded},
      {'name': 'Furniture Assembly', 'icon': Icons.event_seat_rounded},
    ],
    'Electrical & Wiring': [
      {'name': 'Installation', 'icon': Icons.electrical_services_rounded},
      {'name': 'Repair', 'icon': Icons.build_rounded},
      {'name': 'Maintenance', 'icon': Icons.handyman_rounded},
      {'name': 'Smart home', 'icon': Icons.home_repair_service_rounded},
    ],
    'Automotive': [
      {'name': 'Car wash', 'icon': Icons.local_car_wash_rounded},
      {'name': 'Car detailing', 'icon': Icons.auto_fix_high_rounded},
      {'name': 'Car rental', 'icon': Icons.car_rental_rounded},
      {'name': 'Car repair/mechanic', 'icon': Icons.car_repair_rounded},
      {'name': 'Motorcycle repair', 'icon': Icons.two_wheeler_rounded},
    ],
    'Moving': [
      {'name': 'House moving', 'icon': Icons.home_work_rounded},
      {'name': 'Office relocation', 'icon': Icons.business_rounded},
      {'name': 'Lorry rental', 'icon': Icons.local_shipping_rounded},
    ],
    'Health': [
      {'name': 'Personal Trainer', 'icon': Icons.fitness_center_rounded},
      {'name': 'Yoga Instructor', 'icon': Icons.self_improvement_rounded},
    ],
    'Pet Services': [
      {'name': 'Pet grooming', 'icon': Icons.content_cut_rounded},
      {'name': 'Pet boarding', 'icon': Icons.hotel_rounded},
      {'name': 'Vet consultation', 'icon': Icons.medical_services_rounded},
    ],
    'Safety': [
      {'name': 'Surge protector installation', 'icon': Icons.bolt_rounded},
      {'name': 'Lighting protection system', 'icon': Icons.flash_on_rounded},
      {'name': 'Smoke detector installation', 'icon': Icons.sensors_rounded},
      {'name': 'Fire alarm system setup', 'icon': Icons.fire_extinguisher_rounded},
    ],
    'Event': [
      {'name': 'Dj services', 'icon': Icons.headset_rounded},
      {'name': 'Emcee / host', 'icon': Icons.mic_external_on_rounded},
      {'name': 'Catering', 'icon': Icons.restaurant_rounded},
      {'name': 'Photography', 'icon': Icons.camera_alt_rounded},
    ],
    'Others': [
      {'name': 'Other Services', 'icon': Icons.miscellaneous_services_rounded},
    ],
  };

  static List<Map<String, dynamic>> getHomeCategories() {
    return allCategories;
  }
}
