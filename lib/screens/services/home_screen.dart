import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../dashboards/customer_home.dart';
import 'search_page.dart';
import 'service_details.dart';
import 'categories_screen.dart';
import 'subcategory_providers_screen.dart';
import 'category_detail_screen.dart';
import 'top_rated_screen.dart';
import '../misc/notifications_screen.dart';
import '../../utils/categories_data.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/ai_recommendation_service.dart';
import '../../widgets/skeleton_box.dart';

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
  // PageController for non-infinite, left-aligned banner
  final PageController _bannerController = PageController(viewportFraction: 0.85, initialPage: 0);
  Timer? _bannerTimer;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _servicesList = [];
  List<Map<String, dynamic>> _aiRecommendedServices = [];
  bool _isLoadingServices = true;
  bool _isLoadingRecommendations = false;
  String _currentLocation = "Detecting...";
  final Set<String> _savedServiceIds = {};

  List<Map<String, dynamic>> get _categories => AppCategories.getHomeCategories();

  final List<String> popularFilters = ['All', 'Nearby', 'Cleaning', 'Repairing'];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-scroll removed per user request
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingServices = true);
    await Future.wait([
      _fetchUserData(),
      _fetchServices(),
      _determinePosition(),
    ]);
    if (mounted) setState(() => _isLoadingServices = false);
    _generateAIRecommendations();
  }

  Future<void> _generateAIRecommendations() async {
    if (_userData == null || _servicesList.isEmpty) return;
    
    final List<dynamic> userPreferences = _userData!['services'] ?? [];
    if (userPreferences.isEmpty) return;

    if (mounted) setState(() => _isLoadingRecommendations = true);

    final prefsList = userPreferences.map((e) => e.toString()).toList();
    
    final aiRecs = await AiRecommendationService.getRecommendations(
      userPreferences: prefsList,
      userLocation: _currentLocation,
      allServices: _servicesList,
    );

    if (mounted) {
      setState(() {
        _aiRecommendedServices = aiRecs;
        _isLoadingRecommendations = false;
      });
    }
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
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

  List<Map<String, dynamic>> get _topRatedServices {
    final list = List<Map<String, dynamic>>.from(_servicesList);
    list.sort((a, b) {
      final rA = (a['averageRating'] ?? 0).toDouble();
      final rB = (b['averageRating'] ?? 0).toDouble();
      return rB.compareTo(rA); // Highest rating first
    });
    return list;
  }

  List<Map<String, dynamic>> get recommendedServices {
    if (_aiRecommendedServices.isNotEmpty) return _aiRecommendedServices;

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
            _buildCategoriesRow(),
            const SizedBox(height: 32),
            _buildBanner(),
            const SizedBox(height: 24),
            _buildRecommendationSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Top Rated', 'See All', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TopRatedScreen(),
                ),
              );
            }),
            const SizedBox(height: 8),
            _buildServicesList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String address = _currentLocation;
    if (_currentLocation == "Detecting..." && _userData != null) {
      address = _userData!['address'] ?? 'Detecting...';
      if (address.isEmpty) address = 'Detecting...';
    }

    String name = _userData?['name'] ?? _userData?['fullName'] ?? 'User';
    String firstName = name.split(' ')[0];
    String profileImageUrl = _userData?['profileUrl'] ?? _userData?['profileImageUrl'] ?? '';

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
                  child: Row(
                    children: [
                      // User Profile Picture
                      GestureDetector(
                        onTap: () {
                          CustomerHome.setIndex(context, 3);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white.withValues(alpha: 0.8),
                            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                            child: profileImageUrl.isEmpty 
                              ? Text(
                                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFFF6B00),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ) 
                              : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Greeting and Location
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, $firstName',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontWeight: FontWeight.w400, // Unbolded
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: GoogleFonts.outfit(
                                      color: Colors.black, // Darker (solid)
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
        Padding(
          padding: const EdgeInsets.only(left: 18), // Aligns first card with categories
          child: SizedBox(
            height: 165,
            width: double.infinity,
            child: PageView.builder(
              controller: _bannerController,
              clipBehavior: Clip.none,
              padEnds: false, // Align first card to the left of the container
              onPageChanged: (int page) {
                setState(() {
                  _currentBannerPage = page;
                });
              },
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12), // Consistent gap and size
                  child: _getBannerCardByIndex(index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _getBannerCardByIndex(int index) {
    if (index == 0) {
      return _buildBannerCard(
        bgColor: const Color(0xFFFFD700), // Yellow
        textColor: const Color(0xFF1E293B),
        glowColor: const Color(0xFFB8860B),
        badgeText: '✦ Top Rated Pros',
        title: 'Book your service now!',
        btnLabel: 'Book Now →',
        btnColors: const [Colors.white, Color(0xFFF1F5F9)],
        btnTextColor: const Color(0xFF1E293B),
        assetPath: 'assets/images/firstpromotion.png',
      );
    } else if (index == 1) {
      return _buildBannerCard(
        bgColor: const Color(0xFFFF6B00), // Orange
        textColor: Colors.white,
        glowColor: const Color(0xFFFFD700),
        badgeText: '🕐 Quick & Easy',
        title: 'Find trusted pros near you!',
        btnLabel: 'Explore →',
        btnColors: const [Colors.white, Color(0xFFF1F5F9)],
        btnTextColor: const Color(0xFFFF6B00),
        assetPath: 'assets/images/secondpromotion.tiff',
        imageScale: 1.4, // Even bigger to match user request
      );
    } else {
      return _buildBannerCard(
        bgColor: const Color(0xFF64748B), // Grey
        textColor: Colors.white,
        glowColor: const Color(0xFF94A3B8),
        badgeText: '🎁 Exclusive Offer',
        title: 'Refer a friend, earn rewards!',
        btnLabel: 'Share Now →',
        btnColors: const [Colors.white, Color(0xFFF1F5F9)],
        btnTextColor: const Color(0xFF64748B),
        assetPath: 'assets/images/thirdpromotion.png',
        imageScale: 0.9, // Slightly smaller for better balance
      );
    }
  }

  Widget _buildBannerCard({
    required Color bgColor,
    required Color textColor,
    required Color glowColor,
    required String badgeText,
    required String title,
    required String btnLabel,
    required List<Color> btnColors,
    Color btnTextColor = Colors.white,
    required String assetPath,
    double imageScale = 1.0,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16), // Matched with Card2
      ),
      child: Stack(
        children: [
          // Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Text content
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 10), // Reduced vertical padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: textColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.1,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: btnColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            btnLabel,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: btnTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right: Image
              if (assetPath.isNotEmpty)
                Expanded(
                  flex: 6, // Increased flex for a much bigger image
                  child: Transform.scale(
                    scale: imageScale,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.fitHeight, // Fills the entire card height
                      alignment: Alignment.bottomRight,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRow() {
    return SizedBox(
      height: 100, // Slightly bigger for tighter gaps
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final String name = cat['name']?.toString() ?? 'Category';
          final bool isAsset = cat['isAsset'] == true;
          final String assetPath = cat['assetPath']?.toString() ?? '';
          final IconData icon = cat['icon'] as IconData? ?? Icons.category_outlined;
          final Color bgColor = Colors.grey.shade100; // Slightly darker grey for better contrast
          final Color iconColor = const Color(0xFF475569);

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
              width: 100, // Slightly bigger for tighter gaps
              margin: const EdgeInsets.only(right: 8), // Reduced gap
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
                          width: 44, // Reduced from 52
                          height: 44, // Reduced from 52
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            icon,
                            color: iconColor,
                            size: 36, // Reduced from 44
                          ),
                        )
                      : Icon(
                          icon,
                          color: iconColor,
                          size: 36, // Reduced from 44
                        ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 10, // Reduced from 11
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
    );
  }


  Widget _buildRecommendationSection() {
    if (_isLoadingRecommendations) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Recommendation', '', () {}),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                width: 170,
                margin: const EdgeInsets.only(right: 18),
                child: const SkeletonBox(width: 170, height: 260, borderRadiusValue: 16),
              ),
            ),
          ),
        ],
      );
    }

    final list = recommendedServices.isNotEmpty ? recommendedServices : _servicesList.take(5).toList();
    
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommendation', '', () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 290, // Reduced from 310 to match shorter cards
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
    double ratingValue = (s['averageRating'] ?? 0).toDouble();
    String rating = ratingValue == 0 ? "New" : ratingValue.toStringAsFixed(1);
    String providerProfileUrl = s['providerProfileUrl'] ?? ''; 
    String servicePhotoUrl = s['servicePhotoUrl'] ?? ''; 

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: s)));
      },
      child: Container(
        width: 240, // Increased width as requested
        margin: const EdgeInsets.only(right: 18), 
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2), // Minimized bottom gap
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5), 
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), // Square bottom
              child: Image.network(
                servicePhotoUrl.isNotEmpty ? servicePhotoUrl : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                height: 155, 
                width: double.infinity, 
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SkeletonBox(
                    width: double.infinity, 
                    height: 155, 
                    borderRadiusValue: 12,
                  );
                },
                errorBuilder: (_, __, ___) => Image.network(
                  'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', 
                  height: 155, 
                  width: double.infinity, 
                  fit: BoxFit.cover
                ),
              ),
            ),
            const SizedBox(height: 6), // Reduced from 10
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
            const SizedBox(height: 2), // Reduced from 6

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
            const SizedBox(height: 6), // Reduced from 8

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
        children: _topRatedServices.take(4).map((s) => _buildServiceCardList(s)).toList(),
      ),
    );
  }

  Widget _buildServiceCardList(Map<String, dynamic> s) {
    String serviceId = s['serviceId'] ?? '';
    String title = s['title'] ?? 'Elite Service';
    String providerName = s['providerName'] ?? 'Elite Pro';
    String price = s['price']?.toString() ?? '0';
    double ratingValue = (s['averageRating'] ?? 0).toDouble();
    int reviewsCount = s['reviewCount'] ?? 0;
    String rating = ratingValue == 0 ? "New" : ratingValue.toStringAsFixed(1);
    String reviews = reviewsCount.toString(); 
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


