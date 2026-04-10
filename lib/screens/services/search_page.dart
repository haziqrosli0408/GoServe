import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gooservee/screens/misc/map_picker_screen.dart';
import 'package:gooservee/screens/services/location_range_screen.dart';
import '../bookings/booking_screen.dart';
import 'service_details.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchQuery = "";
  String _selectedSort = 'Popular';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allServices = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSearchSubmitted = false;
  final Set<String> _savedServiceIds = {};
  
  // Filter States
  RangeValues _priceRange = const RangeValues(0, 500);
  double _minRating = 0.0;
  String _pricingOption = 'By Hour';
  String _selectedLocationText = 'All over Malaysia';
  double _locationRangeKm = 0; // 0 means no filter
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _fetchUserData().then((_) => _detectCurrentLocation());
    _fetchServices();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _userData = data;
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

  Future<void> _detectCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? 'Unknown';
        String state = place.administrativeArea ?? '';
        String country = place.country ?? '';
        
        String fullAddress = "$city, $state, $country";
        
        setState(() {
          if (_userData == null) {
            _userData = {'address': fullAddress};
          } else {
            _userData!['address'] = fullAddress;
          }
        });
      }
    } catch (e) {
      debugPrint("Error detecting location: $e");
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

  Future<void> _updateUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (context) => const MapPickerScreen()),
      );

      if (result != null && mounted) {
        final String newAddress = result['address'];
        
        setState(() {
          _userData?['address'] = newAddress;
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'address': newAddress});
            
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    }
  }

  Future<void> _fetchServices() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('services').where('isActive', isEqualTo: true).get();
      if (mounted) {
        setState(() {
          _allServices = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _suggestions {
    if (searchQuery.isEmpty) return [];
    
    final Set<String> suggestionSet = {};
    final query = searchQuery.toLowerCase();

    for (var s in _allServices) {
      final title = s['title'] as String? ?? '';
      final category = s['category'] as String? ?? '';
      
      if (title.toLowerCase().contains(query)) {
        suggestionSet.add(title);
      }
      
      if (category.toLowerCase().contains(query)) {
        suggestionSet.add(category);
      }

      final providerName = s['providerName'] as String? ?? '';
      if (providerName.toLowerCase().contains(query)) {
        suggestionSet.add(providerName);
      }
    }
    
    return suggestionSet.toList()..sort((a, b) => a.toLowerCase().indexOf(query).compareTo(b.toLowerCase().indexOf(query)));
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (searchQuery.isEmpty) return [];
    
    var results = _allServices.where((s) {
      final title = (s['title'] as String?)?.toLowerCase() ?? '';
      final category = (s['category'] as String?)?.toLowerCase() ?? '';
      final providerName = (s['providerName'] as String?)?.toLowerCase() ?? '';
      final providerAddress = (s['providerAddress'] as String?)?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();

      bool matchesQuery = title.contains(query) ||
          category.contains(query) ||
          providerName.contains(query) ||
          providerAddress.contains(query);

      if (!matchesQuery) return false;

      // Price Filter
      double price = double.tryParse(s['price']?.toString() ?? '0') ?? 0.0;
      if (price < _priceRange.start || price > _priceRange.end) return false;

      // Rating Filter (Placeholder rating 4.9 for now, replace with actual if available)
      double rating = 4.9; 
      if (rating < _minRating) return false;

      // Pricing Option Filter (Assuming 'type' field exists, or similar)
      if (_pricingOption != 'All') {
        final type = (s['pricingType'] as String?) ?? 'By Hour';
        if (type != _pricingOption) return false;
      }

      // Location Range Filter
      if (_locationRangeKm > 0 && _userLocation != null) {
        double providerLat = s['providerLat'] ?? 0.0;
        double providerLng = s['providerLng'] ?? 0.0;
        
        // If provider has no coordinates, ignore them if a distance filter is set
        if (providerLat == 0 && providerLng == 0) return false;

        double distanceMeters = Geolocator.distanceBetween(
          _userLocation!.latitude, _userLocation!.longitude,
          providerLat, providerLng,
        );
        if (distanceMeters > _locationRangeKm * 1000) return false;
      }

      return true;
    }).toList();

    if (_selectedSort == 'Rating') {
      results.sort((a, b) => (4.9).compareTo(4.9)); // Placeholder sort
    } else if (_selectedSort == 'Price: Low to High') {
      results.sort((a, b) {
        double priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
        double priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0.0;
        return priceA.compareTo(priceB);
      });
    } else if (_selectedSort == 'Price: High to Low') {
      results.sort((a, b) {
        double priceA = double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
        double priceB = double.tryParse(b['price']?.toString() ?? '0') ?? 0.0;
        return priceB.compareTo(priceA);
      });
    } else if (_selectedSort == 'Nearest') {
      String userAddress = _userData?['address']?.toString() ?? 'Kuala Lumpur, Malaysia';
      String userState = userAddress.split(',').length >= 2 
          ? userAddress.split(',')[userAddress.split(',').length - 2].trim().toLowerCase() 
          : userAddress.toLowerCase();
      
      results.sort((a, b) {
        bool aMatches = (a['providerAddress'] as String?)?.toLowerCase().contains(userState) ?? false;
        bool bMatches = (b['providerAddress'] as String?)?.toLowerCase().contains(userState) ?? false;
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        return 0;
      });
    }

    return results;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 1. Header with Title at center and Close icon at right
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'Filter',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // 1. Sort By Section
                        Text(
                          'Sort by',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildSortItem('Popular', setModalState),
                              const Divider(height: 1, thickness: 0.5, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                              _buildSortItem('Rating', setModalState),
                              const Divider(height: 1, thickness: 0.5, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                              _buildSortItem('Price: Low to High', setModalState),
                              const Divider(height: 1, thickness: 0.5, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16),
                              _buildSortItem('Price: High to Low', setModalState),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 2. Location Range Section
                        Text(
                          'Location Range',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            if (_userLocation == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fetching your location, please wait or ensure location services are enabled.')),
                              );
                              return;
                            }
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationRangeScreen(
                                  initialLocation: _userLocation!,
                                  initialRangeKm: _locationRangeKm == 0 ? 10 : _locationRangeKm,
                                ),
                              ),
                            );
                            
                            if (result != null && result is double) {
                              setModalState(() {
                                _locationRangeKm = result;
                                _selectedLocationText = 'Within ${_locationRangeKm.round()} km';
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _selectedLocationText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: const Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 3. Price Range Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Price Range',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'RM${_priceRange.start.round()} - RM${_priceRange.end.round()}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: const Color(0xFFFF6B00),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 1000,
                          activeColor: const Color(0xFFFF6B00),
                          inactiveColor: Colors.grey.shade200,
                          onChanged: (values) {
                            setModalState(() => _priceRange = values);
                          },
                        ),
                        const SizedBox(height: 32),

                        // 4. Rating Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rating',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '${_minRating.toStringAsFixed(1)}+ Stars',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: const Color(0xFFFF6B00),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _minRating,
                          min: 0,
                          max: 5,
                          divisions: 5,
                          activeColor: const Color(0xFFFF6B00),
                          inactiveColor: Colors.grey.shade200,
                          onChanged: (value) {
                            setModalState(() => _minRating = value);
                          },
                        ),
                        const SizedBox(height: 32),

                        // 5. Pricing Option Section
                        Text(
                          'Pricing Option',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildPricingOption('By Hour', setModalState),
                            const SizedBox(width: 12),
                            _buildPricingOption('One Time', setModalState),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  
                  // Bottom Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  _selectedSort = 'Popular';
                                  _priceRange = const RangeValues(0, 500);
                                  _minRating = 0.0;
                                  _pricingOption = 'By Hour';
                                  _locationRangeKm = 0;
                                  _selectedLocationText = 'All over Malaysia';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Reset',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {}); // Update main screen state
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B00),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Apply',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortItem(String label, StateSetter setModalState) {
    bool isSelected = _selectedSort == label;
    return GestureDetector(
      onTap: () {
        setModalState(() => _selectedSort = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF475569),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6B00), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingOption(String option, StateSetter setModalState) {
    bool isSelected = _pricingOption == option;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() => _pricingOption = option);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6B00).withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF6B00) : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              option,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String userAddress = _userData?['address']?.toString() ?? '';
    if (userAddress.isEmpty) userAddress = 'Kuala Lumpur, Malaysia';
    
    String userState = userAddress;
    if (userAddress.contains(',')) {
      final parts = userAddress.split(',');
      if (parts.length >= 2) {
        userState = parts[parts.length - 2].trim();
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search', style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Location Header
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSearchSubmitted 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            sizeCurve: Curves.easeInOut,
            secondChild: const SizedBox(width: double.infinity),
            firstChild: GestureDetector(
              onTap: _updateUserLocation,
              child: Container(
                color: Colors.transparent, // Ensures entire area is clickable
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Current Location', 
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF000000), size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            userState, 
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Grey Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onTap: () {
                        if (_isSearchSubmitted) {
                          setState(() => _isSearchSubmitted = false);
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                          _isSearchSubmitted = false;
                        });
                      },
                      onSubmitted: (value) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _isSearchSubmitted = true);
                      },
                      style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search for services...',
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showFilterBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Matches search bar
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF1E293B), size: 22),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),


          
          // Content
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF000000)))
              : (_isSearchSubmitted ? _buildSearchResults() : _buildSuggestions()),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _suggestions;
    if (searchQuery.isEmpty) return const SizedBox();

    if (suggestions.isEmpty) {
      return Center(
        child: Text('No keywords found', style: GoogleFonts.outfit(color: Colors.grey.shade400)),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history, color: Colors.grey, size: 18),
          title: Text(suggestion, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1E293B))),
          trailing: const Icon(Icons.north_west, color: Colors.grey, size: 16),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              searchQuery = suggestion;
              _searchController.text = suggestion;
              _isSearchSubmitted = true;
            });
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredServices;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade100),
            const SizedBox(height: 16),
            Text('No results found for "$searchQuery"', style: GoogleFonts.outfit(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7, 
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final s = results[index];
        return _buildResultCard(s);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> s) {
    String serviceId = s['serviceId'] ?? '';
    String title = s['title'] ?? 'Elite Service';
    String providerName = s['providerName'] ?? 'Pro Provider';
    String price = s['price']?.toString() ?? '85';
    String rating = '4.9';
    String providerProfileUrl = s['providerProfileUrl'] ?? '';
    String servicePhotoUrl = s['servicePhotoUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: s)));
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
                      fontSize: 15,
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
                    size: 20,
                    color: _savedServiceIds.contains(serviceId) ? const Color(0xFFFF6B00) : Colors.grey.shade400,
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

  Widget _buildSortChip(String label) {
    bool isSelected = _selectedSort == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSort = label;
        });
      },
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
}
