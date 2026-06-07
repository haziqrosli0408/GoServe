import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'service_details.dart';

class TopRatedScreen extends StatefulWidget {
  const TopRatedScreen({super.key});

  @override
  State<TopRatedScreen> createState() => _TopRatedScreenState();
}

class _TopRatedScreenState extends State<TopRatedScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool _isLoading = true;
  final Set<String> _savedServiceIds = {};
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late AnimationController _starController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _starSlideAnimation;
  
  final Color headerColor = const Color(0xFFE2E8F0); // Bright Grey for Top Rated
  final Color contentColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchUserData();
    _fetchProviders();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _starController = AnimationController(
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


    _starSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _starController,
      curve: Curves.easeOutBack,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _starController.forward();
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _starController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredProviders = _allProviders.where((p) {
        final title = (p['title'] as String?)?.toLowerCase() ?? '';
        final provider = (p['providerName'] as String?)?.toLowerCase() ?? '';
        return title.contains(query) || provider.contains(query);
      }).toList();
    });
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
      Position? userPosition;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          userPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
        }
      } catch (e) {
        debugPrint("Error getting location: $e");
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      // Dynamically fetch approved reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('status', isEqualTo: 'Approved')
          .get();
      final allReviews = reviewsSnapshot.docs.map((d) => d.data()).toList();

      if (mounted) {
        setState(() {
          var mappedProviders = snapshot.docs.map((doc) {
            final data = doc.data();
            data['serviceId'] = doc.id;
            
            final serviceReviews = allReviews.where((r) => r['serviceId'] == doc.id).toList();
            if (serviceReviews.isNotEmpty) {
              double sum = 0;
              for (var r in serviceReviews) {
                sum += (r['rating'] as num).toDouble();
              }
              data['averageRating'] = sum / serviceReviews.length;
              data['reviewCount'] = serviceReviews.length;
            } else {
              data['averageRating'] = 0.0;
              data['reviewCount'] = 0;
            }
            return data;
          }).toList();

          if (userPosition != null) {
            mappedProviders = mappedProviders.where((p) {
              final dynamic rawLat = p['providerLat'] ?? p['latitude'] ?? p['lat'];
              final dynamic rawLng = p['providerLng'] ?? p['longitude'] ?? p['lng'];
              double? pLat;
              double? pLng;
              if (rawLat != null && rawLng != null) {
                pLat = (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat.toString());
                pLng = (rawLng is num) ? rawLng.toDouble() : double.tryParse(rawLng.toString());
              }
              if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
                double distanceMeters = Geolocator.distanceBetween(
                  userPosition!.latitude, userPosition!.longitude,
                  pLat, pLng,
                );
                return distanceMeters <= 50000; // 50km radius
              }
              return false; // Skip if no valid location
            }).toList();
          }
          
          mappedProviders.sort((a, b) => ((b['averageRating'] ?? 0).toDouble()).compareTo((a['averageRating'] ?? 0).toDouble()));
          
          _allProviders = mappedProviders;
          _filteredProviders = _allProviders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching top rated: $e");
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
        backgroundColor: headerColor,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: null,
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
                        height: 160, // Reduced height
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Reduced bottom padding
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
                            hintText: 'Search for top experts...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B00)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Top Rated Services',
                        style: GoogleFonts.outfit(
                          color: contentColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Transform.translate(
                        offset: const Offset(0, -25),
                        child: SlideTransition(
                          position: _starSlideAnimation,
                          child: FadeTransition(
                            opacity: _starController, // Use star controller for independent fade
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Image.asset('assets/images/star.png', width: 35, height: 35),
                                Transform.translate(
                                  offset: const Offset(-8, 0),
                                  child: Image.asset('assets/images/star.png', width: 70, height: 70),
                                ),
                                Transform.translate(
                                  offset: const Offset(-16, 0),
                                  child: Image.asset('assets/images/star.png', width: 45, height: 45),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                ),
              ),
            )
          else if (_filteredProviders.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Light yellow background
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_border, size: 48, color: Color(0xFFFFC107)),
          ),
          const SizedBox(height: 24),
          Text(
            'No Top Rated Services',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any highly rated\nservices yet.',
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
    String name = p['providerName'] ?? 'Provider';
    String title = p['title'] ?? 'Service'; 
    String price = p['price']?.toString() ?? '0';
    double ratingValue = (p['averageRating'] ?? 0).toDouble();
    int reviewsCount = p['reviewCount'] ?? 0;
    String rating = ratingValue == 0 ? "New" : "${ratingValue.toStringAsFixed(1)} ($reviewsCount)";
    String profileUrl = p['providerProfileUrl'] ?? '';
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
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
                ) : Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey)),
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
                    maxLines: 1,
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
                        text: 'RM$price',
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
