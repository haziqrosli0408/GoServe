import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
  List<Map<String, dynamic>> _allProviders = []; // Keep original list for filtering
  bool _isLoading = true;
  final Set<String> _savedServiceIds = {};
  String _selectedFilter = 'All';
  Position? _currentPosition;

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
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        final query = widget.queryName.toLowerCase();
        
        // Dynamically fetch approved reviews
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('status', isEqualTo: 'Approved')
            .get();
        final allReviews = reviewsSnapshot.docs.map((d) => d.data()).toList();

        final filteredList = snapshot.docs.map((doc) {
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
        }).where((s) {
           final category = (s['category'] as String?)?.toLowerCase() ?? '';
           final title = (s['title'] as String?)?.toLowerCase() ?? '';
           return category.contains(query) || title.contains(query);
        }).toList();

        setState(() {
          _allProviders = filteredList;
          _providers = List.from(_allProviders);
          _isLoading = false;
        });
        
        // After fetching, if 'Nearest' was selected or we want to pre-fetch location
        if (_selectedFilter == 'Nearest') {
          _handleFilterSelection('Nearest');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFilterSelection(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _isLoading = (filter == 'Nearest' && _currentPosition == null);
    });

    if (filter == 'Nearest' && _currentPosition == null) {
      await _determinePosition();
    }

    _applySorting();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    List<Map<String, dynamic>> sortedList = List.from(_allProviders);

    switch (_selectedFilter) {
      case 'Highest Rated':
        sortedList.sort((a, b) {
          final rA = (a['averageRating'] ?? 0).toDouble();
          final rB = (b['averageRating'] ?? 0).toDouble();
          return rB.compareTo(rA);
        });
        break;
      case 'Lowest Price':
        sortedList.sort((a, b) {
          final pA = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
          final pB = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
          return pA.compareTo(pB);
        });
        break;
      case 'Nearest':
        if (_currentPosition != null) {
          sortedList.sort((a, b) {
            final latA = (a['providerLat'] ?? 0).toDouble();
            final lngA = (a['providerLng'] ?? 0).toDouble();
            final latB = (b['providerLat'] ?? 0).toDouble();
            final lngB = (b['providerLng'] ?? 0).toDouble();

            if (latA == 0 || latB == 0) return 0;

            final distA = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              latA,
              lngA,
            );
            final distB = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              latB,
              lngB,
            );
            return distA.compareTo(distB);
          });
        }
        break;
      default:
        // 'All' - no specific sorting beyond default
        break;
    }

    setState(() {
      _providers = sortedList;
    });
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
                _buildSortChip('All'),
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
                          childAspectRatio: 0.58,
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

  Widget _buildSortChip(String label) {
    final bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => _handleFilterSelection(label),
      child: Container(
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
    int reviewsCount = p['reviewCount'] ?? 0;
    String rating = ratingValue == 0 ? "New" : "${ratingValue.toStringAsFixed(1)} ($reviewsCount)";
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
            AspectRatio(
              aspectRatio: 1.0,
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
            const SizedBox(height: 12),

            // Row 1: Title and Bookmark Icon
            Row(
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
                          fontSize: 14,
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
                  radius: 9,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty 
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 9, fontWeight: FontWeight.w600)) 
                    : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
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
