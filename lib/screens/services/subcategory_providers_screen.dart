import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final Set<String> _savedServiceIds = {};

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchProviders();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            if (data != null && data['savedServices'] != null) {
              _savedServiceIds.clear();
              _savedServiceIds.addAll(List<String>.from(data['savedServices']));
            }
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _toggleSaveService(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (_savedServiceIds.contains(serviceId)) {
        _savedServiceIds.remove(serviceId);
      } else {
        _savedServiceIds.add(serviceId);
      }
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'savedServices': _savedServiceIds.toList(),
      });
    } catch (e) {
      debugPrint("Error updating saved services: $e");
    }
  }

  Future<void> _fetchProviders() async {
    try {
      // 🔹 Fetch from 'services' collection for real service data
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          final query = widget.queryName.toLowerCase();
          
          // Filter services where category or title matches the selected subcategory
          _providers = snapshot.docs.map((doc) => doc.data()).where((s) {
             final category = (s['category'] as String?)?.toLowerCase() ?? '';
             final title = (s['title'] as String?)?.toLowerCase() ?? '';
             return category.contains(query) || title.contains(query);
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
            fontWeight: FontWeight.w600,
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
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.62,
                        ),
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
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
              fontWeight: FontWeight.w600,
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
    String serviceId = p['serviceId'] ?? '';
    String name = p['providerName'] ?? p['name'] ?? 'Provider';
    String title = p['title'] ?? widget.title; 
    String price = p['price']?.toString() ?? '85';
    double ratingValue = (p['averageRating'] ?? 0).toDouble();
    String rating = ratingValue == 0 ? "New" : ratingValue.toStringAsFixed(1);
    String profileUrl = p['providerProfileUrl'] ?? p['profileUrl'] ?? '';
    String servicePhotoUrl = p['servicePhotoUrl'] ?? '';

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
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: servicePhotoUrl.isNotEmpty ? Image.network(
                  servicePhotoUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network('https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', width: double.infinity, fit: BoxFit.cover),
                ) : Image.network(
                  'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Row 1: Title and Bookmark Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleSaveService(serviceId),
                  child: Icon(
                    _savedServiceIds.contains(serviceId) ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                    color: _savedServiceIds.contains(serviceId) ? const Color(0xFFFF6B00) : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Price and Rating
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'From ',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextSpan(
                        text: 'RM$price/hr',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6B00),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ' · ',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 16),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: Provider Profile and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty 
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 10, fontWeight: FontWeight.w600)) 
                    : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
