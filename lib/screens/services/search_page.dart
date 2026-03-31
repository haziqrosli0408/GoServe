import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service_details.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProviders = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSearchSubmitted = false;

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
    
    return _allProviders.where((p) {
      final name = (p['name'] as String?)?.toLowerCase() ?? '';
      final List<dynamic> services = p['services'] ?? [];
      final address = (p['address'] as String?)?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();

      return name.contains(query) ||
          services.any((s) => s.toString().toLowerCase().contains(query)) ||
          address.contains(query);
    }).toList();
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
        title: Text('Search', style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Location Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Current Location', 
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF000000), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userState, 
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
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
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    _isSearchSubmitted = false;
                  });
                },
                onSubmitted: (value) {
                  setState(() => _isSearchSubmitted = true);
                },
                style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search for services or providers...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
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
        child: Text('No keywords found', style: GoogleFonts.inter(color: Colors.grey.shade400)),
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
          title: Text(suggestion, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B))),
          trailing: const Icon(Icons.north_west, color: Colors.grey, size: 16),
          onTap: () {
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
            Text('No results found for "$searchQuery"', style: GoogleFonts.inter(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final p = results[index];
        return _buildResultCard(p);
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> p) {
    String name = p['name'] ?? 'Provider';
    List<dynamic> services = p['services'] ?? [];
    String category = services.isNotEmpty ? services.first.toString() : 'Cleaning';
    String description = p['description'] ?? 'Full sanitization and aesthetic restoration for your space.';
    String price = p['price'] ?? '85';
    String profileUrl = p['profileUrl'] ?? '';
    String rating = '4.9';
    // String reviews = '1.2k'; // Removed as unused

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(
          provider: p,
        )));
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
            // Image with Elite Badge
            Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: profileUrl.isNotEmpty ? DecorationImage(
                      image: NetworkImage(profileUrl),
                      fit: BoxFit.cover,
                    ) : DecorationImage(
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
                      style: GoogleFonts.inter(
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
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                  // Title
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Description
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'RM$price',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6B00),
                              ),
                            ),
                            TextSpan(
                              text: '/hr',
                              style: GoogleFonts.inter(
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
