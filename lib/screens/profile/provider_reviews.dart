import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProviderReviewsPage extends StatefulWidget {
  final String? providerId;
  const ProviderReviewsPage({super.key, this.providerId});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  String activeFilter = 'All';
  final TextEditingController _responseController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  bool _isSubmitting = false;
  
  /// The effective provider ID to query reviews for.
  /// Uses the explicit providerId if given, otherwise falls back to the current user.
  String? get _effectiveProviderId => widget.providerId ?? user?.uid;
  
  /// Whether this is a read-only view (customer viewing someone else's reviews).
  bool get _isReadOnly => widget.providerId != null && widget.providerId != user?.uid;

  void _showResponseModal(String reviewId, String customerName, String comment, String? existingResponse) {
    _responseController.text = existingResponse ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0), // Slate 200
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingResponse != null ? 'Edit Response' : 'Respond to Review',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // Slate 50
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            child: Text(
                              customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            customerName,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: const Color(0xFF475569), // Slate 600
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _responseController,
                  maxLines: 4,
                  maxLength: 500,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: "Thank the customer and address their feedback...",
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8), // Slate 400
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    counterStyle: GoogleFonts.outfit(fontSize: 11),
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () async {
                      if (_responseController.text.trim().isEmpty) return;
                      
                      setModalState(() => _isSubmitting = true);
                      
                      try {
                        await FirebaseFirestore.instance.collection('reviews').doc(reviewId).update({
                          'providerResponse': _responseController.text.trim(),
                          'respondedAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Response saved successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving response: $e')),
                          );
                        }
                      } finally {
                        setModalState(() => _isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            "Save Response",
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Reviews & Ratings",
          style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _effectiveProviderId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('providerId', isEqualTo: _effectiveProviderId)
                  .where('status', isEqualTo: 'Approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                List<int> starCounts = [0, 0, 0, 0, 0]; // 1, 2, 3, 4, 5 stars
                
                for (var doc in allReviews) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] ?? 0).toInt();
                  if (rating > 0 && rating <= 5) {
                    totalRating += rating;
                    starCounts[rating - 1]++;
                  }
                }
                
                final double avgRating = allReviews.isNotEmpty ? totalRating / allReviews.length : 0.0;

                // Apply filter
                List<DocumentSnapshot> filteredReviews = allReviews.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] ?? 0).toInt();
                  final hasResponse = data['providerResponse'] != null;

                  if (activeFilter == 'All') return true;
                  if (activeFilter == '5 Stars') return rating == 5;
                  if (activeFilter == '4 Stars') return rating == 4;
                  if (activeFilter == '3 Stars') return rating == 3;
                  if (activeFilter == 'Responded') return hasResponse;
                  if (activeFilter == 'Pending Response') return !hasResponse;
                  return true;
                }).toList();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildRatingOverview(avgRating, allReviews.length, starCounts),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterHeaderDelegate(
                        onFilterChanged: (filter) => setState(() => activeFilter = filter),
                        activeFilter: activeFilter,
                      ),
                    ),
                    if (filteredReviews.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              "No reviews match this filter",
                              style: GoogleFonts.outfit(color: Colors.grey.shade500),
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
                            return _buildReviewCard(doc.id, data);
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
            "No reviews yet",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When customers review your services, they will appear here.",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview(double avgRating, int totalReviews, List<int> starCounts) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4F46E5).withValues(alpha: 0.05), const Color(0xFF4F46E5).withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w600),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 16,
                    color: index < avgRating.round() ? Colors.amber : Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$totalReviews reviews",
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((stars) {
                final count = starCounts[stars - 1];
                final percentage = totalReviews > 0 ? count / totalReviews : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        "$stars ★",
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.white,
                            color: const Color(0xFF4F46E5),
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

  Widget _buildReviewCard(String reviewId, Map<String, dynamic> review) {
    final customerId = review['userId'] ?? '';
    final fallbackCustomerName = review['userName'] ?? 'Customer';
    final fallbackCustomerImage = review['userProfileUrl'] ?? '';
    final rating = (review['rating'] ?? 0).toInt();
    final service = review['serviceName'] ?? 'Service';
    final comment = review['comment'] ?? '';
    final response = review['providerResponse'];
    
    DateTime dt = DateTime.now();
    if (review['createdAt'] != null) {
      dt = (review['createdAt'] as Timestamp).toDate();
    }
    final date = DateFormat('MMM d, yyyy').format(dt);

    return FutureBuilder<DocumentSnapshot>(
      future: customerId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(customerId).get() : null,
      builder: (context, snapshot) {
        String customerName = fallbackCustomerName;
        String customerImage = fallbackCustomerImage;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName = userData['name'] ?? customerName;
          customerImage = userData['profileUrl'] ?? customerImage;
        }

        if (customerImage == 'null') {
          customerImage = '';
        }

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
              ClipOval(
                child: customerImage.isNotEmpty
                    ? Image.network(
                        customerImage,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Text(
                              customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                              style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                            style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      service,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
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
          const SizedBox(height: 8),
          if (comment.isNotEmpty) ...[
            Text(
              comment,
              style: GoogleFonts.outfit(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 12),
          ],
          
          if (response != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Text(
                        "Your Response",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    response, 
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          if (!_isReadOnly)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showResponseModal(reviewId, customerName, comment, response),
                  style: TextButton.styleFrom(
                    backgroundColor: response != null ? Colors.grey[100] : const Color(0xFF4F46E5),
                    foregroundColor: response != null ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    response != null ? 'Edit Response' : 'Respond',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: response != null ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
      }
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onFilterChanged;
  final String activeFilter;

  _FilterHeaderDelegate({
    required this.onFilterChanged,
    required this.activeFilter,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final filters = ['All', '5 Stars', '4 Stars', '3 Stars', 'Responded', 'Pending Response'];

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
              selectedColor: const Color(0xFF4F46E5),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
