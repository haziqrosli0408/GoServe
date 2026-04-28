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
      {
        'name': 'House Cleaning', 
        'icon': Icons.cleaning_services_rounded,
        'assetPath': 'assets/icons/cleaning.png',
        'isAsset': true,
      },
      {
        'name': 'Move in / Move out cleaning', 
        'icon': Icons.cleaning_services_rounded,
        'assetPath': 'assets/icons/cleaningmoveinmoveout.png',
        'isAsset': true,
      },
      {
        'name': 'Plumbing', 
        'icon': Icons.plumbing_rounded,
        'assetPath': 'assets/icons/Plumbing.png',
        'isAsset': true,
      },
      {
        'name': 'Aircond Service', 
        'icon': Icons.ac_unit_rounded,
        'assetPath': 'assets/icons/Aircond.png',
        'isAsset': true,
      },
      {
        'name': 'Pest control', 
        'icon': Icons.bug_report_rounded,
        'assetPath': 'assets/icons/pestcontrol.png',
        'isAsset': true,
      },
      {
        'name': 'Furniture Assembly', 
        'icon': Icons.event_seat_rounded,
        'assetPath': 'assets/icons/furniture.png',
        'isAsset': true,
      },
    ],
    'Electrical & Wiring': [
      {
        'name': 'Installation', 
        'icon': Icons.electrical_services_rounded,
        'assetPath': 'assets/icons/Installation.png',
        'isAsset': true,
      },
      {
        'name': 'Repair', 
        'icon': Icons.build_rounded,
        'assetPath': 'assets/icons/repair.png',
        'isAsset': true,
      },
      {
        'name': 'Maintenance', 
        'icon': Icons.handyman_rounded,
        'assetPath': 'assets/icons/maintenance.png',
        'isAsset': true,
      },
      {
        'name': 'Smart home', 
        'icon': Icons.home_repair_service_rounded,
        'assetPath': 'assets/icons/smarthome.png',
        'isAsset': true,
      },
    ],
    'Automotive': [
      {
        'name': 'Car wash', 
        'icon': Icons.local_car_wash_rounded,
        'assetPath': 'assets/icons/carwash.png',
        'isAsset': true,
      },
      {
        'name': 'Car detailing', 
        'icon': Icons.auto_fix_high_rounded,
        'assetPath': 'assets/icons/cardetailing.png',
        'isAsset': true,
      },
      {
        'name': 'Car rental', 
        'icon': Icons.car_rental_rounded,
        'assetPath': 'assets/icons/carrental.png',
        'isAsset': true,
      },
      {
        'name': 'Car repair/mechanic', 
        'icon': Icons.car_repair_rounded,
        'assetPath': 'assets/icons/carrepair.png',
        'isAsset': true,
      },
      {
        'name': 'Motorcycle repair', 
        'icon': Icons.two_wheeler_rounded,
        'assetPath': 'assets/icons/motorcyclerepair.png',
        'isAsset': true,
      },
    ],
    'Moving': [
      {
        'name': 'House moving', 
        'icon': Icons.home_work_rounded,
        'assetPath': 'assets/icons/housemoving.png',
        'isAsset': true,
      },
      {
        'name': 'Office relocation', 
        'icon': Icons.business_rounded,
        'assetPath': 'assets/icons/officerelocation.png',
        'isAsset': true,
      },
      {
        'name': 'Lorry rental', 
        'icon': Icons.local_shipping_rounded,
        'assetPath': 'assets/icons/lorryrental.png',
        'isAsset': true,
      },
    ],
    'Health': [
      {
        'name': 'Personal Trainer', 
        'icon': Icons.fitness_center_rounded,
        'assetPath': 'assets/icons/personaltrainer.png',
        'isAsset': true,
      },
      {
        'name': 'Yoga Instructor', 
        'icon': Icons.self_improvement_rounded,
        'assetPath': 'assets/icons/yogainstructor.png',
        'isAsset': true,
      },
    ],
    'Pet Services': [
      {
        'name': 'Pet grooming', 
        'icon': Icons.content_cut_rounded,
        'assetPath': 'assets/icons/petgrooming.png',
        'isAsset': true,
      },
      {
        'name': 'Pet boarding', 
        'icon': Icons.hotel_rounded,
        'assetPath': 'assets/icons/petboarding.png',
        'isAsset': true,
      },
      {
        'name': 'Vet consultation', 
        'icon': Icons.medical_services_rounded,
        'assetPath': 'assets/icons/vetconsultation.png',
        'isAsset': true,
      },
    ],
    'Safety': [
      {
        'name': 'Surge protector installation', 
        'icon': Icons.bolt_rounded,
        'assetPath': 'assets/icons/surgeprotector.png',
        'isAsset': true,
      },
      {
        'name': 'Lighting protection system', 
        'icon': Icons.flash_on_rounded,
        'assetPath': 'assets/icons/lightingprotection.png',
        'isAsset': true,
      },
      {
        'name': 'Smoke detector installation', 
        'icon': Icons.sensors_rounded,
        'assetPath': 'assets/icons/smokedetector.png',
        'isAsset': true,
      },
      {
        'name': 'Fire alarm system setup', 
        'icon': Icons.fire_extinguisher_rounded,
        'assetPath': 'assets/icons/firealarm.png',
        'isAsset': true,
      },
    ],
    'Event': [
      {
        'name': 'Dj services', 
        'icon': Icons.headset_rounded,
        'assetPath': 'assets/icons/dj.png',
        'isAsset': true,
      },
      {
        'name': 'Emcee / host', 
        'icon': Icons.mic_external_on_rounded,
        'assetPath': 'assets/icons/emcee.png',
        'isAsset': true,
      },
      {
        'name': 'Catering', 
        'icon': Icons.restaurant_rounded,
        'assetPath': 'assets/icons/catering.png',
        'isAsset': true,
      },
      {
        'name': 'Photography', 
        'icon': Icons.camera_alt_rounded,
        'assetPath': 'assets/icons/photography.png',
        'isAsset': true,
      },
    ],
    'Others': [
      {'name': 'Other Services', 'icon': Icons.miscellaneous_services_rounded},
    ],
  };

  static List<Map<String, dynamic>> getHomeCategories() {
    return allCategories;
  }
}
