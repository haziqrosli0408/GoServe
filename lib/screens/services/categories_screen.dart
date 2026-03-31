import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = const [
      {'name': 'Cleaning', 'icon': Icons.cleaning_services_outlined},
      {'name': 'Repairing', 'icon': Icons.construction_outlined},
      {'name': 'Painting', 'icon': Icons.format_paint_outlined},
      {'name': 'Laundry', 'icon': Icons.local_laundry_service_outlined},
      {'name': 'Plumbing', 'icon': Icons.plumbing_outlined},
      {'name': 'Moving', 'icon': Icons.local_shipping_outlined},
      {'name': 'Electrical', 'icon': Icons.electrical_services_outlined},
      {'name': 'Gardening', 'icon': Icons.yard_outlined},
      {'name': 'Carpentry', 'icon': Icons.handyman_outlined},
      {'name': 'Pest Control', 'icon': Icons.bug_report_outlined},
      {'name': 'Home Security', 'icon': Icons.security_outlined},
      {'name': 'Interior Design', 'icon': Icons.home_work_outlined},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Categories',
          style: GoogleFonts.inter(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final String name = cat['name'] as String;
          final IconData icon = cat['icon'] as IconData;

          return GestureDetector(
            onTap: () {
              // Handle category click (e.g., search with pre-filled category)
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5), // Bright light orange bg
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Icon(icon, color: Colors.black, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
