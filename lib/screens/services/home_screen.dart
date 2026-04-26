import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_page.dart';
import 'service_details.dart';
import 'categories_screen.dart';
import 'subcategory_providers_screen.dart';
import 'category_detail_screen.dart';
import '../misc/notifications_screen.dart';
import '../../utils/categories_data.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'All';
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  int _currentBannerPage = 0;
  // Use a large initial page for infinite scroll
  final PageController _bannerController = PageController(viewportFraction: 0.91, initialPage: 300);
  Timer? _bannerTimer;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _servicesList = [];
  bool _isLoadingServices = true;
  String _currentLocation = "Detecting...";
  final Set<String> _savedServiceIds = {};

  List<Map<String, dynamic>> get _categories => AppCategories.getHomeCategories();

  final List<String> popularFilters = ['All', 'Nearby', 'Cleaning', 'Repairing'];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchServices();
    _determinePosition();

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerController.hasClients) {
        int nextPage = _bannerController.page!.round() + 1;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _currentLocation = "Kuala Lumpur, Malaysia");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentLocation = "Kuala Lumpur, Malaysia");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentLocation = "Kuala Lumpur, Malaysia");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _currentLocation = "${place.locality ?? 'Unknown'}, ${place.administrativeArea ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentLocation = "Home, KL"); // Fallback city
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try fetching from users first
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        // If not found in users, try providers
        if (!doc.exists) {
          doc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
        }

        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _userData = data;
            // Sync saved services from Firestore
            if (data['savedServices'] != null) {
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

  Future<void> _fetchServices() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('services').where('isActive', isEqualTo: true).get();
      if (mounted) {
        setState(() {
          _servicesList = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    return _servicesList.where((s) {
      final query = searchQuery.toLowerCase();
      
      final title = (s['title'] as String?)?.toLowerCase() ?? '';
      final category = (s['category'] as String?)?.toLowerCase() ?? '';
      final providerName = (s['providerName'] as String?)?.toLowerCase() ?? '';
      final providerAddress = (s['providerAddress'] as String?)?.toLowerCase() ?? '';

      final matchesSearch = title.contains(query) ||
          category.contains(query) ||
          providerName.contains(query) ||
          providerAddress.contains(query);

      bool matchesCategory = true;
      if (selectedCategory == 'Nearby') {
        String userFullAddress = _userData?['address']?.toString() ?? 'Kuala Lumpur, Malaysia';
        String userState = userFullAddress;
        if (userFullAddress.contains(',')) {
          final parts = userFullAddress.split(',');
          if (parts.length >= 2) {
             userState = parts[parts.length - 2].trim();
          }
        }
        matchesCategory = providerAddress.contains(userState.toLowerCase());
      } else if (selectedCategory != 'All') {
        matchesCategory = category.contains(selectedCategory.toLowerCase());
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> get recommendedServices {
    if (_userData == null || _userData!['services'] == null) return [];
    final List<dynamic> userPreferences = _userData!['services'] ?? [];
    
    final normalizedPrefs = userPreferences.map((e) => e.toString().toLowerCase()).toList();
    
    if (normalizedPrefs.isEmpty) return [];

    return _servicesList.where((s) {
      final category = (s['category'] as String?)?.toLowerCase() ?? '';
      final title = (s['title'] as String?)?.toLowerCase() ?? '';
      
      return normalizedPrefs.any((pref) => 
        category.contains(pref) || 
        title.contains(pref) || 
        pref.contains(category)
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoadingServices 
          ? _buildSkeletonLoader()
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFF6B00).withValues(alpha: 0.15), // Lighter top
                    const Color(0xFFFF6B00).withValues(alpha: 0.65), // Darker at search bar area
                    Colors.white, // Fade to white
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildBanner(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildSectionHeader('Categories', 'See All', () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const CategoriesScreen(),
                ),
              );
            }),
            const SizedBox(height: 16),
            _buildCategoriesGrid(),
            const SizedBox(height: 8),
            _buildRecommendationSection(),
            const SizedBox(height: 8),
            _buildSectionHeader('Top Rated', 'See All', () {}),
            const SizedBox(height: 16),
            _buildServicesList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String address = _currentLocation;
    
    // If not detected yet or user has a stored profile address, we could prioritize that.
    // But per user request, we focus on real location.
    if (_currentLocation == "Detecting..." && _userData != null) {
      address = _userData!['address'] ?? 'Detecting...';
      if (address.isEmpty) address = 'Detecting...';
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontWeight: FontWeight.w300,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 52,
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
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
                    },
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '', // Keep empty as we use AnimatedTextKit
                      prefixIcon: const Icon(Icons.search, color: Colors.black45, size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  Positioned(
                    left: 48, // Consistent with prefixIcon width
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Text(
                            'Find your best ',
                            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                          ),
                          DefaultTextStyle(
                            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                            child: AnimatedTextKit(
                              repeatForever: true,
                              animatedTexts: [
                                TypewriterAnimatedText(
                                  'services...',
                                  speed: const Duration(milliseconds: 100),
                                ),
                                TypewriterAnimatedText(
                                  'service providers...',
                                  speed: const Duration(milliseconds: 100),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Column(
      children: [
        SizedBox(
          height: 210, // Increased height to prevent bottom overflow
          width: double.infinity,
          child: PageView.builder(
            controller: _bannerController,
            clipBehavior: Clip.none,
            onPageChanged: (int page) {
              setState(() {
                _currentBannerPage = page % 3;
              });
            },
            itemCount: 999, // Infinite scroll
            itemBuilder: (context, index) {
              final realIndex = index % 3;
              return AnimatedBuilder(
                animation: _bannerController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_bannerController.position.hasContentDimensions) {
                    value = _bannerController.page! - index;
                    value = (1 - (value.abs() * 0.04)).clamp(0.0, 1.0);
                  } else {
                    // Initial load fallback: index 300 is the first displayed card
                    value = index == 300 ? 1.0 : 0.92;
                  }

                  return Center(
                    child: Transform.scale(
                      scale: value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0), // Removed gap for perfect alignment
                        child: _getBannerCardByIndex(realIndex),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentBannerPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentBannerPage == index
                    ? const Color(0xFFFF6B00)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getBannerCardByIndex(int index) {
    if (index == 0) {
      return _buildBannerCard(
        bgColors: const [Color(0xFF1A1A2E), Color(0xFF16213E)],
        glowColor: const Color(0xFFFF6B00),
        badgeText: '✦ Top Rated Pros',
        title: 'Book your\nservice now!',
        btnLabel: 'Book Now →',
        btnColors: const [Color(0xFFFF8C42), Color(0xFFFF6B00)],
        imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=800&auto=format&fit=crop',
      );
    } else if (index == 1) {
      return _buildBannerCard(
        bgColors: const [Color(0xFF0F3460), Color(0xFF1A5276)],
        glowColor: const Color(0xFF00B4DB),
        badgeText: '🕐 Quick & Easy',
        title: 'Find trusted\npros near you!',
        btnLabel: 'Explore →',
        btnColors: const [Color(0xFF0083B0), Color(0xFF00B4DB)],
        imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
      );
    } else {
      return _buildBannerCard(
        bgColors: const [Color(0xFF2D1B69), Color(0xFF11998E)],
        glowColor: const Color(0xFF11998E),
        badgeText: '🎁 Exclusive Offer',
        title: 'Refer a friend,\nearn rewards!',
        btnLabel: 'Share Now →',
        btnColors: const [Color(0xFF38EF7D), Color(0xFF11998E)],
        imageUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=800&auto=format&fit=crop',
      );
    }
  }

  Widget _buildBannerCard({
    required List<Color> bgColors,
    required Color glowColor,
    required String badgeText,
    required String title,
    required String btnLabel,
    required List<Color> btnColors,
    required String imageUrl,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle glows
          Positioned(
            left: -30,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.07),
              ),
            ),
          ),

          // Content Row
          Row(
            children: [
              // Left: Text content
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 10, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: glowColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: glowColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: glowColor,
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),

                      // Button
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              height: MediaQuery.of(context).size.height * 0.75,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: const CategoriesScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: btnColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            btnLabel,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right: Image with gradient bleed
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [bgColors.last, Colors.transparent],
                      stops: const [0, 0.15],
                    ).createShader(rect),
                    blendMode: BlendMode.dstOut,
                    child: Image.network(
                      imageUrl,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18), // Kept screen gap
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10, // Reduced from 16
          crossAxisSpacing: 10, // Reduced from 16
          mainAxisExtent: 115, // Slightly increased to fill the space
        ),
        itemCount: 6, // Show only 6 cards
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
              final subcats = AppCategories.subcategoryMap[name];
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
              height: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14), // Sharper curve
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isAsset
                      ? Image.asset(
                          assetPath,
                          width: 52, // Increased from 40
                          height: 52, // Increased from 40
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            icon,
                            color: iconColor,
                            size: 44, // Increased from 36
                          ),
                        )
                      : Icon(
                          icon,
                          color: iconColor,
                          size: 44, // Increased from 36
                        ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                      height: 1.1,
                    ),
                    maxLines: 2, // Allow 2 lines for 3-column grid
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildRecommendationSection() {
    final list = recommendedServices.isNotEmpty ? recommendedServices : _servicesList.take(5).toList();
    
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommendation', 'See All', () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 280, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildServiceCardRecommendation(list[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCardRecommendation(Map<String, dynamic> s) {
    String serviceId = s['serviceId'] ?? '';
    String title = s['title'] ?? 'Elite Home Service';
    String providerName = s['providerName'] ?? 'Pro Provider';
    String price = s['price']?.toString() ?? '25';
    String rating = '4.9';
    String providerProfileUrl = s['providerProfileUrl'] ?? ''; 
    String servicePhotoUrl = s['servicePhotoUrl'] ?? ''; 

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: s)));
      },
      child: Container(
        width: 170, 
        margin: const EdgeInsets.only(right: 18), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                servicePhotoUrl.isNotEmpty ? servicePhotoUrl : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                height: 160, 
                width: 170, 
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SkeletonBox(width: 170, height: 160, borderRadiusValue: 16);
                },
                errorBuilder: (_, __, ___) => Image.network(
                  'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', 
                  height: 160, 
                  width: 170, 
                  fit: BoxFit.cover
                ),
              ),
            ),
            const SizedBox(height: 10), 
            // Row 1: Title and Favorite Icon
            SizedBox(
              height: 42, 
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14, 
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleSaveService(serviceId),
                    child: Icon(
                      _savedServiceIds.contains(serviceId) ? Icons.bookmark : Icons.bookmark_border,
                      size: 18, 
                      color: _savedServiceIds.contains(serviceId) ? const Color(0xFFFF6B00) : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6), 

            // Row 2: Price and Rating
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'From ',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextSpan(
                        text: 'RM$price${s['priceType'] == 'one-time' ? '' : '/hr'}',
                        style: GoogleFonts.outfit(
                          fontSize: 13, 
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
                    fontSize: 12, 
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 12), 
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: GoogleFonts.outfit(
                    fontSize: 11, 
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), 

            // Row 3: Provider Profile and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 9, 
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: providerProfileUrl.isNotEmpty ? NetworkImage(providerProfileUrl) : null,
                  child: providerProfileUrl.isEmpty 
                    ? Text(providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 8, fontWeight: FontWeight.w600)) 
                    : null,
                ),
                const SizedBox(width: 6), 
                Expanded(
                  child: Text(
                    providerName,
                    style: GoogleFonts.outfit(
                      fontSize: 10, 
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


  Widget _buildSectionHeader(String title, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFF6B00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (_isLoadingServices) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      ));
    }

    if (_filteredServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("No services found", style: GoogleFonts.outfit(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _filteredServices.take(5).map((s) => _buildServiceCardList(s)).toList(),
      ),
    );
  }

  Widget _buildServiceCardList(Map<String, dynamic> s) {
    String serviceId = s['serviceId'] ?? '';
    String title = s['title'] ?? 'Elite Service';
    String providerName = s['providerName'] ?? 'Elite Pro';
    String price = s['price']?.toString() ?? '85';
    String rating = '4.8'; 
    String reviews = '195'; 
    String providerProfileUrl = s['providerProfileUrl'] ?? '';
    String servicePhotoUrl = s['servicePhotoUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(
          provider: s,
        )));
      },
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        color: Colors.white,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    servicePhotoUrl.isNotEmpty ? servicePhotoUrl : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                    width: 140, 
                    height: 140, 
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SkeletonBox(width: 140, height: 140, borderRadiusValue: 16);
                    },
                    errorBuilder: (_, __, ___) => Image.network(
                      'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', 
                      width: 140, 
                      height: 140, 
                      fit: BoxFit.cover
                    ),
                  ),
                ),
                const SizedBox(width: 18), // Increased from 16
                // Details
                Expanded(
                  child: SizedBox(
                    height: 140, // Increased from 120
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Title and Bookmark Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 17, // Increased from 16
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleSaveService(serviceId),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                _savedServiceIds.contains(serviceId) ? Icons.bookmark : Icons.bookmark_border,
                                size: 22, // Increased from 20
                                color: _savedServiceIds.contains(serviceId) ? const Color(0xFFFF6B00) : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // Increased from 2
                      
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFC107), size: 15), // Increased from 14
                          const SizedBox(width: 4),
                          Text(
                            '$rating ($reviews) · \$\$',
                            style: GoogleFonts.outfit(
                              fontSize: 13, // Increased from 12
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Spacer(), 

                      // Price
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'From ',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            TextSpan(
                              text: 'RM$price',
                              style: GoogleFonts.outfit(
                                fontSize: 17, // Increased from 16
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFF6B00),
                              ),
                            ),
                            if (s['priceType'] != 'one-time')
                              TextSpan(
                                text: '/hr',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10), // Increased from 8

                      // Provider Profile Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 11, // Increased from 9
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: providerProfileUrl.isNotEmpty ? NetworkImage(providerProfileUrl) : null,
                            child: providerProfileUrl.isEmpty 
                              ? Text(providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 10, fontWeight: FontWeight.w600)) 
                              : null,
                          ),
                          const SizedBox(width: 8), // Increased from 6
                          Expanded(
                            child: Text(
                              providerName,
                              style: GoogleFonts.outfit(
                                fontSize: 13, // Increased from 12
                                fontWeight: FontWeight.w500, // Increased from normal
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  const Color(0xFFFF6B00).withValues(alpha: 0.1),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 80, height: 14),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(width: 200, height: 20),
                    const SkeletonBox(width: 32, height: 32, isCircle: true),
                  ],
                ),
                const SizedBox(height: 24),
                const SkeletonBox(width: double.infinity, height: 52, borderRadiusValue: 12),
              ],
            ),
          ),
          
          // Banner Skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonBox(
              width: double.infinity, 
              height: 180, 
              borderRadiusValue: 24
            ),
          ),
          const SizedBox(height: 24),

          // Categories Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(width: 120, height: 20),
                    const SkeletonBox(width: 50, height: 14),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 100,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => const SkeletonBox(width: double.infinity, height: 100, borderRadiusValue: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recommendation Skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 20),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(width: double.infinity, height: 180, borderRadiusValue: 20)),
                    SizedBox(width: 16),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 180, borderRadiusValue: 20)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadiusValue;
  final bool isCircle;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadiusValue = 8,
    this.isCircle = false,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadiusValue),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (0.1 + (_animation.value - 1.0).clamp(0.0, 0.6)).toDouble(),
                (0.3 + (_animation.value - 1.0).clamp(0.0, 0.6)).toDouble(),
                (0.5 + (_animation.value - 1.0).clamp(0.0, 0.6)).toDouble(),
              ],
              colors: [
                Colors.grey[200]!,
                Colors.grey[100]!,
                Colors.grey[200]!,
              ],
            ),
          ),
        );
      },
    );
  }
}
