import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'subcategory_providers_screen.dart';
import 'service_details.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final IconData categoryIcon;
  final List<Map<String, dynamic>> subcategories;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.subcategories,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _filteredSubcategories;
  final TextEditingController _searchController = TextEditingController();
  late Color headerColor;
  late Color contentColor;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool _isLoadingProviders = true;
  final Set<String> _savedServiceIds = {};

  @override
  void initState() {
    super.initState();
    _filteredSubcategories = widget.subcategories;
    _searchController.addListener(_onSearchChanged);
    _initializeColors();
    _fetchUserData();
    _fetchProviders();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -3.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          final categoryQuery = widget.categoryName.toLowerCase();
          
          _allProviders = snapshot.docs.map((doc) {
            final data = doc.data();
            data['serviceId'] = doc.id;
            return data;
          }).where((s) {
             final category = (s['category'] as String?)?.toLowerCase() ?? '';
             return category.contains(categoryQuery);
          }).toList();
          
          _filteredProviders = _allProviders;
          _isLoadingProviders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProviders = false);
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      
      _filteredSubcategories = widget.subcategories
          .where((sub) => sub['name']
              .toString()
              .toLowerCase()
              .contains(query))
          .toList();

      _filteredProviders = _allProviders.where((p) {
        final title = (p['title'] as String?)?.toLowerCase() ?? '';
        final provider = (p['providerName'] as String?)?.toLowerCase() ?? '';
        return title.contains(query) || provider.contains(query);
      }).toList();
    });
  }

  void _initializeColors() {
    final colors = [
      {'bg': const Color(0xFFFFB74D), 'text': Colors.black},
      {'bg': const Color(0xFFFFD600), 'text': Colors.black},
      {'bg': const Color(0xFFE2E8F0), 'text': Colors.black},
    ];

    int index;
    if (widget.categoryName == 'Home Services') {
      index = 0;
    } else {
      index = widget.categoryName.hashCode.abs() % colors.length;
    }
    
    headerColor = colors[index]['bg']!;
    contentColor = colors[index]['text']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.outfit(
            color: contentColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ClipPath(
                      clipper: WaveClipper(),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: headerColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for services...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: contentColor == Colors.white ? const Color(0xFFFF6B00) : contentColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.categoryName != 'Others')
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subcat = _filteredSubcategories[index];
                    final String name = subcat['name'] as String;
                    final bool isAsset = subcat['isAsset'] == true;
                    final String assetPath = subcat['assetPath'] as String? ?? '';
                    final IconData icon = subcat['icon'] as IconData;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubcategoryProvidersScreen(
                              title: name,
                              queryName: name,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isAsset
                                  ? Image.asset(assetPath, width: 32, height: 32)
                                  : Icon(icon, color: const Color(0xFFFF6B00), size: 28),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1F2937),
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _filteredSubcategories.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                'Available Services',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Outfit',
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),

          if (_isLoadingProviders)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                ),
              ),
            )
          else if (_filteredProviders.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No services found in this category',
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildProviderCard(_filteredProviders[index]);
                  },
                  childCount: _filteredProviders.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    String serviceId = p['serviceId'] ?? '';
    String name = p['providerName'] ?? p['name'] ?? 'Provider';
    String title = p['title'] ?? 'Service'; 
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

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);

    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
