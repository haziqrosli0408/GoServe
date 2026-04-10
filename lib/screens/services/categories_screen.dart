import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/categories_data.dart';
import 'category_detail_screen.dart';
import 'subcategory_providers_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final List<Map<String, dynamic>> _categories = AppCategories.getHomeCategories();
  final Map<String, List<Map<String, dynamic>>> _subcategoryMap = AppCategories.subcategoryMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Centered Title
          Text(
            'All Categories',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: _categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories found',
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // Matched Home Screen
                    itemCount: _categories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10, // Matched Home Screen
                      crossAxisSpacing: 10, // Matched Home Screen
                      mainAxisExtent: 115, // Matched Home Screen
                    ),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final String name = cat['name']?.toString() ?? 'Category';
                      final bool isAsset = cat['isAsset'] == true;
                      final String assetPath = cat['assetPath']?.toString() ?? '';
                      final IconData icon = cat['icon'] as IconData? ?? Icons.category_outlined;
                      final Color bgColor = cat['color'] is Color ? cat['color'] as Color : const Color(0xFFF1F5F9);
                      final Color iconColor = cat['iconColor'] is Color ? cat['iconColor'] as Color : const Color(0xFF475569);

                      return GestureDetector(
                        onTap: () {
                          final subcats = _subcategoryMap[name];

                          if (subcats != null && subcats.isNotEmpty) {
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubcategoryProvidersScreen(
                                  title: name,
                                  queryName: name,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isAsset
                                  ? Image.asset(
                                      assetPath,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        icon,
                                        color: iconColor,
                                        size: 44,
                                      ),
                                    )
                                  : Icon(
                                      icon,
                                      color: iconColor,
                                      size: 44,
                                    ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
