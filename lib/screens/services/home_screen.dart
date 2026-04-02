import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_page.dart';
import 'service_details.dart';
import 'categories_screen.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'saved_services_screen.dart';

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
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _providersList = [];
  bool _isLoadingProviders = true;
  String _currentLocation = "Detecting...";
  final Set<String> _savedProviderNames = {};

  final categories = const [
    {'name': 'Plumbing', 'icon': Icons.plumbing_outlined},
    {'name': 'Painting', 'icon': Icons.format_paint_outlined},
    {'name': 'Electrical', 'icon': Icons.electrical_services_outlined},
    {'name': 'Moving', 'icon': Icons.local_shipping_outlined},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services_outlined},
    {'name': 'Landscaping', 'icon': Icons.grass_outlined},
  ];

  final List<String> popularFilters = ['All', 'Nearby', 'Cleaning', 'Repairing'];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchProviders();
    _determinePosition();

    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentBannerPage < 2) {
        _currentBannerPage++;
      } else {
        _currentBannerPage = 0;
      }

      if (_bannerController.hasClients) {
        _bannerController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
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
      if (mounted) setState(() => _currentLocation = "Lagos, Nigeria");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _currentLocation = "Lagos, Nigeria");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentLocation = "Lagos, Nigeria");
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
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() => _userData = doc.data());
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('providers').get();
      if (mounted) {
        setState(() {
          _providersList = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoadingProviders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProviders = false);
    }
  }

  List<Map<String, dynamic>> get filteredProviders {
    return _providersList.where((p) {
      final query = searchQuery.toLowerCase();
      
      final name = (p['name'] as String?)?.toLowerCase() ?? '';
      final List<dynamic> services = p['services'] ?? [];
      final address = (p['address'] as String?)?.toLowerCase() ?? '';

      final matchesSearch = name.contains(query) ||
          services.any((s) => s.toString().toLowerCase().contains(query)) ||
          address.contains(query);

      bool matchesCategory = true;
      if (selectedCategory == 'Nearby') {
        // Simple nearby check: check if the state matches
        String userFullAddress = _userData?['address']?.toString() ?? 'Kuala Lumpur, Malaysia';
        String userState = userFullAddress;
        if (userFullAddress.contains(',')) {
          final parts = userFullAddress.split(',');
          if (parts.length >= 2) {
             userState = parts[parts.length - 2].trim();
          }
        }
        matchesCategory = address.contains(userState.toLowerCase());
      } else if (selectedCategory != 'All') {
        matchesCategory = services.contains(selectedCategory);
      }

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> get recommendedProviders {
    if (_userData == null || _userData!['services'] == null) return [];
    final List<dynamic> userPreferences = _userData!['services'] ?? [];
    
    // Normalize user preferences to lowercase for robust matching
    final normalizedPrefs = userPreferences.map((e) => e.toString().toLowerCase()).toList();
    
    if (normalizedPrefs.isEmpty) return [];

    return _providersList.where((p) {
      final List<dynamic> providerServices = p['services'] ?? [];
      return providerServices.any((s) {
        final serviceName = s.toString().toLowerCase();
        // Match if names are identical or one contains the other (e.g., 'Plumbing' vs 'Plumber')
        return normalizedPrefs.any((pref) => 
          serviceName == pref || 
          serviceName.contains(pref) || 
          pref.contains(serviceName)
        );
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildBanner(),
            const SizedBox(height: 24),
            _buildSectionHeader('Categories', 'See All', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            }),
            const SizedBox(height: 16),
            _buildCategoriesGrid(),
            const SizedBox(height: 24),
            _buildRecommendationSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Top Rated', 'See All', () {}),
            const SizedBox(height: 16),
            _buildProviderList(),
            const SizedBox(height: 32),
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF6B00).withValues(alpha: 0.56),
            Colors.white,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                        Text(
                          address,
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    final savedList = _providersList.where((p) => _savedProviderNames.contains(p['name'])).toList();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SavedServicesScreen(savedProviders: savedList)));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.bookmark_outline, color: Colors.black, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade200),
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
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tune, color: Colors.black54, size: 16),
                              ),
                            ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: PageView(
              controller: _bannerController,
              onPageChanged: (int page) {
                setState(() {
                  _currentBannerPage = page;
                });
              },
              children: [
                _buildBannerCard(
                  bgColors: const [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  glowColor: const Color(0xFFFF6B00),
                  badgeText: '✦ Top Rated Pros',
                  title: 'Book your\nservice now!',
                  btnLabel: 'Book Now →',
                  btnColors: const [Color(0xFFFF8C42), Color(0xFFFF6B00)],
                  imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=800&auto=format&fit=crop',
                ),
                _buildBannerCard(
                  bgColors: const [Color(0xFF0F3460), Color(0xFF1A5276)],
                  glowColor: const Color(0xFF00B4DB),
                  badgeText: '🕐 Quick & Easy',
                  title: 'Find trusted\npros near you!',
                  btnLabel: 'Explore →',
                  btnColors: const [Color(0xFF0083B0), Color(0xFF00B4DB)],
                  imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                ),
                _buildBannerCard(
                  bgColors: const [Color(0xFF2D1B69), Color(0xFF11998E)],
                  glowColor: const Color(0xFF11998E),
                  badgeText: '🎁 Exclusive Offer',
                  title: 'Refer a friend,\nearn rewards!',
                  btnLabel: 'Share Now →',
                  btnColors: const [Color(0xFF38EF7D), Color(0xFF11998E)],
                  imageUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=800&auto=format&fit=crop',
                ),
              ],
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
      ),
    );
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
                  padding: const EdgeInsets.fromLTRB(22, 22, 10, 22),
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
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),

                      // Button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
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
                              fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 110,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  color: const Color(0xFF1F2937),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  cat['name'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildRecommendationSection() {
    // For demo purposes, if recommended is empty, we show a few from the main list
    final list = recommendedProviders.isNotEmpty ? recommendedProviders : _providersList.take(5).toList();
    
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommendation', 'See All', () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildCard2(list[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard2(Map<String, dynamic> p) {
    String name = p['name'] ?? 'Elite Home Services';
    List<dynamic> svcs = p['services'] ?? [];
    String sub = svcs.isNotEmpty ? svcs.first.toString() : 'Expert Professional';
    String price = p['price']?.toString() ?? '25';
    String rating = '4.9';
    String profileUrl = p['profileUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: p)));
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: profileUrl.isNotEmpty ? Image.network(
                profileUrl,
                height: 150,
                width: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.network('https://i.pravatar.cc/150?u=$name', height: 150, width: 160, fit: BoxFit.cover),
              ) : Image.network(
                'https://i.pravatar.cc/150?u=$name',
                height: 150,
                width: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            // Row 1: Title and Favorite Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sub, // Service name
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_savedProviderNames.contains(name)) {
                        _savedProviderNames.remove(name);
                      } else {
                        _savedProviderNames.add(name);
                      }
                    });
                  },
                  child: Icon(
                    _savedProviderNames.contains(name) ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: _savedProviderNames.contains(name) ? Colors.black : Colors.grey.shade400,
                  ),
                ),
              ],
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
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextSpan(
                        text: 'RM$price/hr',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
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
                  backgroundImage: profileUrl.isNotEmpty
                    ? NetworkImage(profileUrl)
                    : NetworkImage('https://i.pravatar.cc/150?u=$name') as ImageProvider,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
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
              fontWeight: FontWeight.bold,
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

  Widget _buildProviderList() {
    if (_isLoadingProviders) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      ));
    }

    if (filteredProviders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("No providers found", style: GoogleFonts.outfit(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: filteredProviders.take(3).map((p) => _buildProviderCard(p)).toList(),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> p) {
    String name = p['name'] ?? 'Unknown Provider';
    List<dynamic> servicesList = p['services'] ?? [];
    String category = servicesList.isNotEmpty ? servicesList.first.toString() : 'Cleaning';
    String rating = '4.8'; 
    String reviews = '195'; 
    String price = p['price']?.toString() ?? '85';
    String profileUrl = p['profileUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(
          provider: p,
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
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: profileUrl.isNotEmpty ? DecorationImage(
                      image: NetworkImage(profileUrl),
                      fit: BoxFit.cover,
                    ) : DecorationImage(
                      image: NetworkImage('https://i.pravatar.cc/150?u=$name'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: SizedBox(
                    height: 120, // Match the image height exactly
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Title and More Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              category, // Displaying Service name
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_savedProviderNames.contains(name)) {
                                  _savedProviderNames.remove(name);
                                } else {
                                  _savedProviderNames.add(name);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2), // Minor alignment tweak
                              child: Icon(
                                _savedProviderNames.contains(name) ? Icons.bookmark : Icons.bookmark_border,
                                size: 20,
                                color: _savedProviderNames.contains(name) ? Colors.black : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$rating ($reviews) · \$\$',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Provider Profile Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundImage: profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : NetworkImage('https://i.pravatar.cc/150?u=$name') as ImageProvider,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(), // Forces the price strictly down to the bottom limit

                      // Price
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'From ',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
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
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Clean bottom margin since extras are removed
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

}
