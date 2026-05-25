import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  String activeFilter = 'All';
  final TextEditingController _responseController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  bool _isSubmitting = false;

  void _showResponseModal(String reviewId, String customerName, String comment, String? existingResponse) {
    _responseController.text = existingResponse ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingResponse != null ? 'Edit Response' : 'Respond to Review',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        comment,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.black54,
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
                  decoration: InputDecoration(
                    hintText: "Thank the customer and address their feedback...",
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () async {
                      if (_responseController.text.trim().isEmpty) return;
                      
                      setModalState(() => _isSubmitting = true);
                      
                      try {
                        await FirebaseFirestore.instance.collection('reviews').doc(reviewId).update({
                          'providerResponse': _responseController.text.trim(),
                          'respondedAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Response saved successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving response: $e')),
                          );
                        }
                      } finally {
                        setModalState(() => _isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[600],
                      shape: const StadiumBorder(),
                    ),
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            "Save Response",
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
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
          style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('providerId', isEqualTo: user!.uid)
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
          colors: [Colors.amber.shade50, Colors.orange.shade50],
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
                            color: Colors.amber,
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
    final customerName = review['userName'] ?? 'Customer';
    final customerImage = review['userProfileUrl'] ?? '';
    final rating = (review['rating'] ?? 0).toInt();
    final service = review['serviceName'] ?? 'Service';
    final comment = review['comment'] ?? '';
    final response = review['providerResponse'];
    
    DateTime dt = DateTime.now();
    if (review['createdAt'] != null) {
      dt = (review['createdAt'] as Timestamp).toDate();
    }
    final date = DateFormat('MMM d, yyyy').format(dt);

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
                backgroundImage: customerImage.isNotEmpty ? NetworkImage(customerImage) : null,
                child: customerImage.isEmpty
                    ? Text(
                        customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                        style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      )
                    : null,
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        "Your Response",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
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
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _showResponseModal(reviewId, customerName, comment, response),
                style: TextButton.styleFrom(
                  backgroundColor: response != null ? Colors.grey[100] : Colors.amber[600],
                  foregroundColor: response != null ? Colors.black54 : Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  response != null ? 'Edit Response' : 'Respond',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
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
              selectedColor: Colors.amber.shade600,
              backgroundColor: Colors.grey.shade100,
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
