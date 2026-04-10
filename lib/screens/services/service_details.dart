import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bookings/booking_screen.dart';
import '../chat/single_chat_screen.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> provider;

  const ServiceDetailsScreen({super.key, required this.provider});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  int _activeTab = 0; // 0: About, 1: Add-ons, 2: Gallery, 3: Reviews
  bool _isSaved = false;
  String? _liveProfileUrl;

  @override
  void initState() {
    super.initState();
    _fetchLiveProviderData();
  }

  Future<void> _fetchLiveProviderData() async {
    try {
      final String providerId = widget.provider['providerId'] ?? '';
      if (providerId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('providers').doc(providerId).get();
        if (doc.exists && mounted) {
          setState(() {
            _liveProfileUrl = doc.data()?['profileUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching live provider data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.provider['providerName'] ?? widget.provider['name'] ?? 'Unknown Provider';
    final List<dynamic> servicesList = widget.provider['services'] ?? [];
    final String category = (widget.provider['category'] as String?) ?? (servicesList.isNotEmpty ? servicesList.first.toString() : 'Service');
    final String description = widget.provider['description'] ?? 'No description available for this service provider.';
    final String price = widget.provider['price'] ?? '0';
    final String profileUrl = _liveProfileUrl ?? widget.provider['providerProfileUrl'] ?? widget.provider['profileUrl'] ?? '';
    final String serviceImageUrl = widget.provider['servicePhotoUrl'] ?? 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=2070&auto=format&fit=crop';
    final String serviceTitle = widget.provider['title'] ?? widget.provider['serviceName'] ?? 'Elite Service';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        _buildHeader(context, serviceImageUrl, profileUrl, name),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 65, 24, 40), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 CUSTOM TAB BAR (Now at the top)
                      _buildTabBar(),
                      
                      const SizedBox(height: 24),
                      
                      // 🔹 TAB CONTENT
                      _buildTabContent(description, price),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooter(context, name, serviceTitle, category, price, serviceImageUrl),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabItem(0, 'About'),
          const SizedBox(width: 8),
          _tabItem(1, 'Add-ons'),
          const SizedBox(width: 8),
          _tabItem(2, 'Gallery'),
          const SizedBox(width: 8),
          _tabItem(3, 'Reviews'),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF6B00) : const Color(0xFFF1F5F9), 
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String description, String price) {
    if (_activeTab == 0) {
      final String serviceTitle = widget.provider['title'] ?? widget.provider['serviceName'] ?? 'Elite Service';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceTitle,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Description',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Service Details',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.provider['details'] != null && (widget.provider['details'] as List).isNotEmpty)
            ...(widget.provider['details'] as List).map((detail) => 
              _buildDetailItem(Icons.check_circle_outline, detail.toString())
            )
          else ...[
            _buildDetailItem(Icons.check_circle_outline, 'Professional specialized equipment'),
            _buildDetailItem(Icons.check_circle_outline, 'Verified & background-checked pro'),
            _buildDetailItem(Icons.check_circle_outline, 'Satisfaction guaranteed service'),
            _buildDetailItem(Icons.check_circle_outline, 'Insured up to RM10,000 damage cover'),
          ],
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(Icons.payments_outlined, color: Color(0xFFFF6B00)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pricing Model', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                    Text('Starting from RM$price${widget.provider['priceType'] == 'one-time' ? '' : '/hr'}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else if (_activeTab == 1) {
      final List<dynamic> addOns = widget.provider['addOns'] ?? [];
      
      if (addOns.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.extension_off_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No add-ons available',
                style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Add-ons',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...addOns.map((addOn) {
            final data = Map<String, dynamic>.from(addOn);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? 'Extra Service',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (data['description'] != null && data['description'].toString().isNotEmpty)
                          Text(
                            data['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ RM${data['price']}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B00),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } else if (_activeTab == 2) {
      final List<dynamic> galleryItems = widget.provider['galleryUrls'] ?? [];
      
      if (galleryItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No gallery images uploaded',
                style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: galleryItems.length,
        itemBuilder: (context, index) {
          final String path = galleryItems[index].toString();
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: path.startsWith('http') 
              ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageError())
              : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageError()),
          );
        },
      );
    } else {
      return Column(
        children: [
          const SizedBox(height: 20),
          _buildReviewItem(
            'Sarah J.', 
            'Oct 24, 2023',
            'Excellent service! Very professional and clean. They even helped me move some of the heavier items back into place.', 
            5,
            reviewImages: [
              'https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?q=80&w=400&auto=format&fit=crop',
              'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?q=80&w=400&auto=format&fit=crop',
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewItem(
            'Michael R.', 
            'Sep 15, 2023',
            'Did a great job with the plumbing. No leaks at all since the repair. Very impressed with the speed.', 
            4,
            reviewImages: [
              'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?q=80&w=400&auto=format&fit=crop',
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewItem(
            'Lina W.', 
            'Aug 10, 2023',
            'Solid work, though I wished they had arrived a few minutes earlier. Overall satisfactory and will use again.', 
            4,
          ),
        ],
      );
    }
  }

  Widget _buildReviewItem(String name, String date, String comment, int rating, {List<String>? reviewImages}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF1F5F9),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      date,
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: i < rating ? const Color(0xFFFF6B00) : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            comment,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          if (reviewImages != null && reviewImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: reviewImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(reviewImages[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String bgUrl, String profileUrl, String name) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: bgUrl.startsWith('http') 
                ? NetworkImage(bgUrl) 
                : FileImage(File(bgUrl)) as ImageProvider, 
              fit: BoxFit.cover
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.4)],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -45,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                      child: profileUrl.isEmpty 
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 24, fontWeight: FontWeight.w600)) 
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: const Color(0xFF4ADE80), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E212C))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('4.9', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                          const SizedBox(width: 4),
                          Text('(128 reviews)', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ),
                ),
                _actionButton(Icons.chat_bubble_rounded, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SingleChatScreen(
                        provider: {
                          ...widget.provider,
                          'providerId': widget.provider['providerId'] ?? widget.provider['id'] ?? '',
                          'providerName': name,
                          'serviceId': widget.provider['serviceId'] ?? widget.provider['id'] ?? '',
                          'title': widget.provider['title'] ?? widget.provider['name'] ?? '',
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF1E212C), size: 20),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF6B00)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String providerName, String serviceTitle, String category, String price, String serviceImageUrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // 🔹 SAVE BUTTON
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_outline, 
                color: _isSaved ? Colors.black : const Color(0xFF1E293B)
              ),
              onPressed: () {
                setState(() {
                  _isSaved = !_isSaved;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isSaved ? 'Saved to your bookmarks!' : 'Removed from bookmarks'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Book Now Button
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BookingPage(
                    serviceName: serviceTitle,
                    providerName: providerName,
                    providerId: widget.provider['providerId'] ?? widget.provider['id'] ?? widget.provider['uid'] ?? '',
                    serviceImage: serviceImageUrl,
                    category: category,
                    price: price,
                    addOns: widget.provider['addOns'],
                  )));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Book Now', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageError() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade300, size: 32),
      ),
    );
  }
}
