import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service_details.dart';

class SavedServicesScreen extends StatefulWidget {
  const SavedServicesScreen({super.key});

  @override
  
  State<SavedServicesScreen> createState() => _SavedServicesScreenState();
}

class _SavedServicesScreenState extends State<SavedServicesScreen> {
  List<Map<String, dynamic>> _savedServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedServices();
  }

  Future<void> _fetchSavedServices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Get saved IDs from user doc
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final List<dynamic> savedIds = userDoc.data()?['savedServices'] ?? [];

      if (savedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _savedServices = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch those services
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      // Dynamically fetch approved reviews to calculate exact rating
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('status', isEqualTo: 'Approved')
          .get();
      final allReviews = reviewsSnapshot.docs.map((d) => d.data()).toList();

      final allServices = snapshot.docs.map((doc) {
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
      
      final filtered = allServices.where((s) => savedIds.contains(s['serviceId'])).toList();

      if (mounted) {
        setState(() {
          _savedServices = filtered.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUnsave(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'savedServices': FieldValue.arrayRemove([serviceId]),
      });
      
      // Refresh list
      _fetchSavedServices();
    } catch (e) {
      debugPrint("Error unsaving service: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B1B1B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Services',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1B1B1B),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _savedServices.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.68, // Matches search page update
                  ),
                  itemCount: _savedServices.length,
                  itemBuilder: (context, index) {
                    return _buildSavedCard(context, _savedServices[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_outline, size: 48, color: Colors.grey.shade200),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved services yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Favorite some providers to quickly access them later!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade300,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(BuildContext context, Map<String, dynamic> provider) {
    String serviceId = provider['serviceId'] ?? '';
    String name = provider['providerName'] ?? provider['name'] ?? 'Elite Pro';
    String title = provider['title'] ?? 'Elite Service';
    String price = provider['price']?.toString() ?? '85';
    String priceType = provider['priceType']?.toString() ?? 'hourly';
    String priceSuffix = priceType == 'one-time' ? '' : '/hr';
    double ratingValue = (provider['averageRating'] ?? 0).toDouble();
    int reviewsCount = provider['reviewCount'] ?? 0;
    String rating = ratingValue == 0 ? "New" : "${ratingValue.toStringAsFixed(1)} ($reviewsCount)";
    String providerProfileUrl = provider['providerProfileUrl'] ?? provider['profileUrl'] ?? '';
    String servicePhotoUrl = provider['servicePhotoUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: provider)));
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
                child: servicePhotoUrl.isNotEmpty 
                  ? Image.network(
                      servicePhotoUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.network('https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', width: double.infinity, fit: BoxFit.cover),
                    ) 
                  : Image.network(
                      'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
              ),
            ),
            const SizedBox(height: 8),
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
                  onTap: () => _toggleUnsave(serviceId),
                  child: const Icon(                   
                    Icons.bookmark, 
                    size: 20, 
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6), 
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
                        text: 'RM$price$priceSuffix',
                        style: GoogleFonts.outfit(
                          fontSize: 15, 
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
                    fontSize: 14, // Increased from 12
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
            Row(
              children: [
                CircleAvatar(
                  radius: 10, 
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: providerProfileUrl.isNotEmpty ? NetworkImage(providerProfileUrl) : null,
                  child: providerProfileUrl.isEmpty 
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 9, fontWeight: FontWeight.w600)) 
                    : null,
                ),
                const SizedBox(width: 6), 
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
