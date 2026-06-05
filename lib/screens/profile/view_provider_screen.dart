import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/service_details.dart';

import 'provider_reviews.dart';

/// A read-only view of a provider's public profile, accessible by customers.
/// Shows: name, profile picture, chat button, stats (bookings, rating), reviews, and services list.
class ViewProviderScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? providerProfileUrl;

  const ViewProviderScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerProfileUrl,
  });

  @override
  State<ViewProviderScreen> createState() => _ViewProviderScreenState();
}

class _ViewProviderScreenState extends State<ViewProviderScreen> {
  Map<String, dynamic>? _providerData;
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  int _bookingsCount = 0;
  double _rating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProviderData();
  }

  Future<void> _fetchProviderData() async {
    try {
      // Fetch provider doc
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();

      Map<String, dynamic> providerInfo = {};
      if (providerDoc.exists) {
        providerInfo = providerDoc.data() ?? {};
      }

      // Also check users collection for additional info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.providerId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        providerInfo = {...userData, ...providerInfo};
      }

      // Fetch bookings count
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: widget.providerId)
          .get();

      // Fetch reviews for rating
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: widget.providerId)
          .where('status', isEqualTo: 'Approved')
          .get();

      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }

      // Fetch services
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: widget.providerId)
          .where('isActive', isEqualTo: true)
          .get();

      final services = servicesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Dynamically compute rating from fetched reviews to keep cards in sync
        final serviceReviews = reviewsSnapshot.docs.where((r) {
          final rData = r.data();
          return rData['serviceId'] == doc.id;
        }).toList();

        if (serviceReviews.isNotEmpty) {
          double sum = 0;
          for (var r in serviceReviews) {
            sum += (r.data()['rating'] as num).toDouble();
          }
          data['averageRating'] = sum / serviceReviews.length;
          data['reviewCount'] = serviceReviews.length;
        } else {
          data['averageRating'] = 0.0;
          data['reviewCount'] = 0;
        }

        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _providerData = providerInfo;
          _bookingsCount = bookingsSnapshot.size;
          _reviewCount = reviewsSnapshot.size;
          _rating = reviewsSnapshot.docs.isNotEmpty
              ? totalRating / reviewsSnapshot.docs.length
              : 0.0;
          _services = services.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching provider data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFFF6B00);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: themeColor),
        ),
      );
    }

    final String name = _providerData?['name'] ?? widget.providerName;
    final String profileUrl = _providerData?['profileUrl'] ??
        widget.providerProfileUrl ??
        '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 🔹 HEADER WITH GRADIENT & PROFILE PICTURE
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        themeColor,
                        themeColor.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                // Back Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Curved White Background Sheet
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                  ),
                ),
                // Profile Image
                Positioned(
                  bottom: 0,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl)
                          : null,
                      child: profileUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: GoogleFonts.outfit(
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔹 PROVIDER INFO & CHAT BUTTON
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Service Provider',
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today_outlined,
                          value: _bookingsCount.toString(),
                          label: 'Bookings',
                          themeColor: themeColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProviderReviewsPage(
                                  providerId: widget.providerId,
                                ),
                              ),
                            );
                          },
                          child: _StatCard(
                            icon: Icons.star_outline_rounded,
                            value: _rating > 0
                                ? _rating.toStringAsFixed(1)
                                : 'New',
                            label: '$_reviewCount Reviews',
                            themeColor: themeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),

          // 🔹 SERVICES HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                'Services by $name',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ),

          // 🔹 SERVICES GRID
          if (_services.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active services',
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildServiceCard(context, _services[index]);
                  },
                  childCount: _services.length,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> service) {
    String title = service['title'] ?? 'Service';
    String price = service['price']?.toString() ?? '0';
    String servicePhotoUrl = service['servicePhotoUrl'] ?? '';
    double avgRating =
        (service['averageRating'] ?? 0).toDouble();
    int reviewCount = service['reviewCount'] ?? 0;
    String ratingText = avgRating > 0 ? "${avgRating.toStringAsFixed(1)} ($reviewCount)" : 'New';
    String priceType = service['priceType'] ?? 'hourly';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailsScreen(provider: service),
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
                child: servicePhotoUrl.isNotEmpty
                    ? Image.network(
                        servicePhotoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Color(0xFFCBD5E1)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                        text: 'RM$price',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6B00),
                        ),
                      ),
                      if (priceType != 'one-time')
                        TextSpan(
                          text: '/hr',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey.shade500,
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
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 4),
                Text(
                  ratingText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
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

/// Stat card widget for the provider's public profile
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color themeColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: themeColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
