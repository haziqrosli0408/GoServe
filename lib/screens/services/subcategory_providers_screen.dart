import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_details.dart';

class SubcategoryProvidersScreen extends StatefulWidget {
  final String title;
  final String queryName; // Category or Subcategory name used to filter in Firestore

  const SubcategoryProvidersScreen({
    super.key,
    required this.title,
    required this.queryName,
  });

  @override
  State<SubcategoryProvidersScreen> createState() => _SubcategoryProvidersScreenState();
}

class _SubcategoryProvidersScreenState extends State<SubcategoryProvidersScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    try {
      // 🔹 Filter by 'services' array containing the queryName
      final snapshot = await FirebaseFirestore.instance
          .collection('providers')
          .get();

      if (mounted) {
        setState(() {
          // Manual filtering locally because user preferences and testing
          // might require case-insensitive or partial matching
          final query = widget.queryName.toLowerCase();
          
          _providers = snapshot.docs.map((doc) => doc.data()).where((p) {
             final List<dynamic> services = p['services'] ?? [];
             return services.any((s) => s.toString().toLowerCase().contains(query));
          }).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          widget.title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Sort Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildSortChip('All', isSelected: true),
                const SizedBox(width: 8),
                _buildSortChip('Highest Rated'),
                const SizedBox(width: 8),
                _buildSortChip('Lowest Price'),
                const SizedBox(width: 8),
                _buildSortChip('Nearest'),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // 🔹 Provider List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : _providers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          return _buildProviderCard(_providers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off, size: 48, color: Colors.orange.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'No Providers Found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any experts for\n"${widget.queryName}" yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    String name = p['name'] ?? 'Provider';
    List<dynamic> services = p['services'] ?? [];
    String category = services.isNotEmpty ? services.first.toString() : 'Service';
    String description = p['description'] ?? 'Expert professional service provider.';
    String price = p['price']?.toString() ?? '85';
    String profileUrl = p['profileUrl'] ?? '';
    String rating = '4.9';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailsScreen(provider: p),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: profileUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profileUrl),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: NetworkImage('https://i.pravatar.cc/150?u=$name'),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'ELITE',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B00),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFF59E0B), size: 12),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'RM$price',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6B00),
                              ),
                            ),
                            TextSpan(
                              text: '/hr',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.bookmark_border,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
