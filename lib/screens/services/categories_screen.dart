import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'category_detail_screen.dart';
import 'subcategory_providers_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = "";

  // All Parent Categories
  final List<Map<String, dynamic>> _allCategories = const [
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

  // Map of Categories that have Subcategories
  // Any category NOT in this map will go straight to the Providers list
  final Map<String, List<Map<String, dynamic>>> _subcategoryMap = const {
    'Plumbing': [
      {'name': 'Toilet Repair', 'icon': Icons.wc},
      {'name': 'Sink & Faucet', 'icon': Icons.water_drop_outlined},
      {'name': 'Pipe Leakage', 'icon': Icons.plumbing_outlined},
      {'name': 'Water Heater', 'icon': Icons.hot_tub_outlined},
    ],
    'Carpentry': [
      {'name': 'Door & Window', 'icon': Icons.door_front_door_outlined},
      {'name': 'Cabinet', 'icon': Icons.kitchen_outlined},
      {'name': 'Furniture Fix', 'icon': Icons.chair_outlined},
      {'name': 'Flooring', 'icon': Icons.grid_view_outlined},
    ],
    // ADD MORE HERE LATER!
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter categories based on search query
    final filteredCategories = _searchQuery.isEmpty
        ? _allCategories
        : _allCategories
            .where((cat) => cat['name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.outfit(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(
                'All Categories',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: const Color(0xFF1E293B),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  // Close search and clear query
                  _isSearching = false;
                  _searchQuery = "";
                  _searchController.clear();
                } else {
                  // Open search
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: filteredCategories.isEmpty
          ? Center(
              child: Text(
                'No categories found',
                style: GoogleFonts.outfit(
                    color: Colors.grey.shade500, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: filteredCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final cat = filteredCategories[index];
                final String name = cat['name'] as String;
                final IconData icon = cat['icon'] as IconData;

                return GestureDetector(
                  onTap: () {
                    // Check if this category has subcategories
                    final subcats = _subcategoryMap[name];

                    if (subcats != null && subcats.isNotEmpty) {
                      // 👉 Navigate to Category Detail Screen (Subcategory Grid)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryDetailScreen(
                            categoryName: name,
                            categoryIcon: icon,
                            subcategories: subcats,
                          ),
                        ),
                      );
                    } else {
                      // 👉 Navigate Directly to Provider List
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubcategoryProvidersScreen(
                            title: name,
                            queryName: name, // Filter Firestore by category name
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: const Color(0xFFFF6B00),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: GoogleFonts.outfit(
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
