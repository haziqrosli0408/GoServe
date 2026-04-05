import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service_details.dart';
import '../misc/map_picker_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchQuery = "";
  String _selectedSort = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProviders = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSearchSubmitted = false;
  final Set<String> _savedProviderNames = {};

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
          setState(() => _userData = doc.data());
        }
      }
    } catch (e) {
      // Ignore
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

  Future<void> _fetchProviders() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('providers').get();
      if (mounted) {
        setState(() {
          _allProviders = snapshot.docs.map((doc) => doc.data()).toList();
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

    for (var p in _allProviders) {
      final name = p['name'] as String? ?? '';
      final List<dynamic> services = p['services'] ?? [];
      
      if (name.toLowerCase().contains(query)) {
        suggestionSet.add(name);
      }
      
      for (var s in services) {
        final serviceName = s.toString();
        if (serviceName.toLowerCase().contains(query)) {
          suggestionSet.add(serviceName);
        }
      }
    }
    
    return suggestionSet.toList()..sort((a, b) => a.toLowerCase().indexOf(query).compareTo(b.toLowerCase().indexOf(query)));
  }

  List<Map<String, dynamic>> get _filteredProviders {
    if (searchQuery.isEmpty) return [];
    
    var results = _allProviders.where((p) {
      final name = (p['name'] as String?)?.toLowerCase() ?? '';
      final List<dynamic> services = p['services'] ?? [];
      final address = (p['address'] as String?)?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          services.any((s) => s.toString().toLowerCase().contains(query)) ||
          address.contains(query);
    }).toList();

    if (_selectedSort == 'Highest Rated') {
      // Mock ratings sort (add real rating prop to providers in Firestore if available)
      results.sort((a, b) => ('4.9').compareTo('4.9'));
    } else if (_selectedSort == 'Lowest Price') {
      results.sort((a, b) {
        double priceA = double.tryParse(a['price']?.toString() ?? '85') ?? 85.0;
        double priceB = double.tryParse(b['price']?.toString() ?? '85') ?? 85.0;
        return priceA.compareTo(priceB);
      });
    } else if (_selectedSort == 'Nearest') {
      String userAddress = _userData?['address']?.toString() ?? 'Kuala Lumpur, Malaysia';
      String userState = userAddress.split(',').length >= 2 
          ? userAddress.split(',')[userAddress.split(',').length - 2].trim().toLowerCase() 
          : userAddress.toLowerCase();
      
      results.sort((a, b) {
        bool aMatches = (a['address'] as String?)?.toLowerCase().contains(userState) ?? false;
        bool bMatches = (b['address'] as String?)?.toLowerCase().contains(userState) ?? false;
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        return 0;
      });
    }

    return results;
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
        title: Text('Search', style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
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
                  hintText: 'Search for services or providers...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),

          // 🔹 Sort Chips (Show only when submitted)
          if (_isSearchSubmitted)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
          
          if (_isSearchSubmitted) const SizedBox(height: 12),
          
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
    final results = _filteredProviders;
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
        childAspectRatio: 0.7, // Adjusted for the new card style
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final p = results[index];
        return _buildResultCard(p);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> p) {
    String name = p['name'] ?? 'Elite Home Services';
    List<dynamic> svcs = p['services'] ?? [];
    String sub = svcs.isNotEmpty ? svcs.first.toString() : 'Expert Professional';
    String price = p['price']?.toString() ?? '85';
    String rating = '4.9';
    String profileUrl = p['profileUrl'] ?? '';
    String servicePhotoUrl = p['servicePhotoUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: p)));
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
                const SizedBox(width: 4),
                Text(
                  '2.5 km',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey.shade400,
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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
