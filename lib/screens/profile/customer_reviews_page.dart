import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CustomerReviewsPage extends StatefulWidget {
  final String? customerId;
  final Color themeColor;

  const CustomerReviewsPage({
    super.key,
    this.customerId,
    this.themeColor = const Color(0xFFFF6B00),
  });

  @override
  State<CustomerReviewsPage> createState() => _CustomerReviewsPageState();
}

class _CustomerReviewsPageState extends State<CustomerReviewsPage> {
  String activeFilter = 'All';

  String get _customerId =>
      widget.customerId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  // Cache to avoid multiple reads for the same provider
  final Map<String, Map<String, String>> _providerCache = {};

  Future<Map<String, String>> _getProviderInfo(String providerId) async {
    if (_providerCache.containsKey(providerId)) {
      return _providerCache[providerId]!;
    }

    try {
      // 1. Try to get from 'providers' collection first
      final pDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      if (pDoc.exists) {
        final data = pDoc.data() as Map<String, dynamic>;
        final String name = (data['companyName'] ?? data['name'] ?? 'Provider').toString();
        final String profileUrl = (data['profileUrl'] ?? data['photoUrl'] ?? '').toString();
        final info = <String, String>{'name': name, 'profileUrl': profileUrl};
        _providerCache[providerId] = info;
        return info;
      }

      // 2. Fallback to 'users' collection
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();

      if (uDoc.exists) {
        final data = uDoc.data() as Map<String, dynamic>;
        final String name = (data['name'] ?? 'Provider').toString();
        final String profileUrl = (data['profileUrl'] ?? '').toString();
        final info = <String, String>{'name': name, 'profileUrl': profileUrl};
        _providerCache[providerId] = info;
        return info;
      }
    } catch (e) {
      debugPrint("Error fetching provider info: $e");
    }

    return <String, String>{'name': 'Provider', 'profileUrl': ''};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: Text(
          "My Reviews & Ratings",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _customerId.isEmpty
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('userId', isEqualTo: _customerId)
                  .where('status', isEqualTo: 'Approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: widget.themeColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final allReviews = snapshot.data!.docs.toList();

                // Sort by createdAt descending
                allReviews.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                // Calculate stats
                double totalRating = 0;
                List<int> starCounts = [0, 0, 0, 0, 0];

                for (var doc in allReviews) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] ?? 0).toInt();
                  if (rating > 0 && rating <= 5) {
                    totalRating += rating;
                    starCounts[rating - 1]++;
                  }
                }

                final double avgRating =
                    allReviews.isNotEmpty ? totalRating / allReviews.length : 0.0;

                // Apply filter
                List<DocumentSnapshot> filteredReviews =
                    allReviews.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] ?? 0).toInt();
                  final hasResponse = data['providerResponse'] != null;

                  if (activeFilter == 'All') return true;
                  if (activeFilter == '5 Stars') return rating == 5;
                  if (activeFilter == '4 Stars') return rating == 4;
                  if (activeFilter == '3 Stars') return rating == 3;
                  if (activeFilter == '2 Stars') return rating == 2;
                  if (activeFilter == '1 Star') return rating == 1;
                  if (activeFilter == 'Responded') return hasResponse;
                  return true;
                }).toList();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildRatingOverview(
                          avgRating, allReviews.length, starCounts),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterHeaderDelegate(
                        onFilterChanged: (filter) =>
                            setState(() => activeFilter = filter),
                        activeFilter: activeFilter,
                        themeColor: widget.themeColor,
                      ),
                    ),
                    if (filteredReviews.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              "No reviews match this filter",
                              style: GoogleFonts.outfit(
                                  color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = filteredReviews[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildReviewCard(data);
                          },
                          childCount: filteredReviews.length,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No reviews written yet",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "When you rate and review services you book, they will appear here along with replies from the provider.",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview(
      double avgRating, int totalReviews, List<int> starCounts) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.themeColor.withValues(alpha: 0.05),
            widget.themeColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: GoogleFonts.outfit(
                    fontSize: 40, fontWeight: FontWeight.w600),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 16,
                    color: index < avgRating.round()
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$totalReviews submitted",
                style:
                    GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((stars) {
                final count = starCounts[stars - 1];
                final percentage =
                    totalReviews > 0 ? count / totalReviews : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        "$stars ★",
                        style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.white,
                            color: widget.themeColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final providerId = review['providerId'] ?? '';
    final rating = (review['rating'] ?? 0).toInt();
    final service = review['serviceName'] ?? 'Service';
    final comment = review['comment'] ?? '';
    final List<dynamic> tags = review['tags'] ?? [];
    final providerResponse = review['providerResponse'] as String?;

    DateTime dt = DateTime.now();
    if (review['createdAt'] != null) {
      dt = (review['createdAt'] as Timestamp).toDate();
    }
    final date = DateFormat('MMM d, yyyy').format(dt);

    return FutureBuilder<Map<String, String>>(
      future: _getProviderInfo(providerId),
      builder: (context, providerSnapshot) {
        final providerInfo = providerSnapshot.data ?? {'name': 'Provider', 'profileUrl': ''};
        final providerName = providerInfo['name']!;
        final providerImage = providerInfo['profileUrl']!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: providerImage.isNotEmpty
                        ? NetworkImage(providerImage)
                        : null,
                    child: providerImage.isEmpty
                        ? Text(
                            providerName.isNotEmpty
                                ? providerName[0].toUpperCase()
                                : 'P',
                            style: GoogleFonts.outfit(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          service,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    date,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 16,
                    color: index < rating ? Colors.amber : Colors.grey[300],
                  ),
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag.toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.themeColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  comment,
                  style: GoogleFonts.outfit(
                      fontSize: 14, height: 1.4, color: Colors.black87),
                ),
              ],
              if (providerResponse != null && providerResponse.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: widget.themeColor),
                          const SizedBox(width: 6),
                          Text(
                            "Response from $providerName",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        providerResponse,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onFilterChanged;
  final String activeFilter;
  final Color themeColor;

  _FilterHeaderDelegate({
    required this.onFilterChanged,
    required this.activeFilter,
    required this.themeColor,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final filters = ['All', 'Responded', '5 Stars', '4 Stars', '3 Stars', '2 Stars', '1 Star'];

    return Container(
      color: Colors.white,
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8, top: 8),
            child: ChoiceChip(
              label: Text(
                filter,
                style: GoogleFonts.outfit(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onFilterChanged(filter),
              selectedColor: themeColor,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? themeColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 50;
  @override
  double get minExtent => 50;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
