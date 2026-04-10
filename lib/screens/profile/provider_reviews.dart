import 'package:flutter/material.dart';

class Review {
  final String id;
  final String customerName;
  final String customerImage;
  final double rating;
  final String date;
  final String service;
  final String comment;
  final String? response;
  final int helpful;

  Review({
    required this.id,
    required this.customerName,
    required this.customerImage,
    required this.rating,
    required this.date,
    required this.service,
    required this.comment,
    this.response,
    required this.helpful,
  });
}

class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  String activeFilter = 'all';
  final TextEditingController _responseController = TextEditingController();

  final List<Review> reviews = [
    Review(
      id: '1',
      customerName: 'Encik Miju',
      customerImage: 'https://i.pravatar.cc/150?u=1',
      rating: 5,
      date: '2024-01-15',
      service: 'Deep House Cleaning',
      comment: 'Absolutely fantastic service! Very thorough and professional.',
      response: 'Thank you so much Miju! Looking forward to serving you again!',
      helpful: 12,
    ),
    Review(
      id: '2',
      customerName: 'Abdul Kasim',
      customerImage: 'https://i.pravatar.cc/150?u=2',
      rating: 4,
      date: '2024-01-12',
      service: 'Office Cleaning',
      comment: 'Kerja yang bagusss',
      helpful: 8,
    ),
    // Add other review data objects here...
  ];

  List<Review> get filteredReviews {
    return reviews.where((review) {
      if (activeFilter == 'all') return true;
      if (activeFilter == 'responded') return review.response != null;
      if (activeFilter == 'pending') return review.response == null;
      return review.rating == double.tryParse(activeFilter);
    }).toList();
  }

  void _showResponseModal(Review review) {
    _responseController.text = review.response ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (context) => Padding(
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
                      review.response != null
                          ? 'Edit Response'
                          : 'Respond to Review',
                      style: const TextStyle(
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
                        review.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        review.comment,
                        style: const TextStyle(
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
                    hintText:
                        "Thank the customer and address their feedback...",
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
                    onPressed: () {
                      // Submit logic here
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[600],
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Reviews & Ratings",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildRatingOverview()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              onFilterChanged:
                  (filter) => setState(() => activeFilter = filter),
              activeFilter: activeFilter,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildReviewCard(filteredReviews[index]),
              childCount: filteredReviews.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[50]!, Colors.orange[50]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            children: [
              const Text(
                "4.6",
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 16,
                    color: index < 4 ? Colors.amber : Colors.grey[300],
                  ),
                ),
              ),
              const Text(
                "234 reviews",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children:
                  [5, 4, 3, 2, 1].map((stars) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            "$stars ★",
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: LinearProgressIndicator(
                              value:
                                  (stars == 5
                                      ? 0.67
                                      : (stars == 4 ? 0.22 : 0.08)),
                              backgroundColor: Colors.white,
                              color: Colors.amber,
                              minHeight: 6,
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

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(review.customerImage)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      review.service,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                review.date,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 14,
                color: index < review.rating ? Colors.amber : Colors.grey[300],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (review.response != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply, size: 14, color: Colors.amber),
                      SizedBox(width: 5),
                      Text(
                        "Your Response",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(review.response!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "${review.helpful} helpful",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showResponseModal(review),
                style: TextButton.styleFrom(
                  backgroundColor:
                      review.response != null
                          ? Colors.grey[100]
                          : Colors.amber[600],
                  foregroundColor:
                      review.response != null ? Colors.black54 : Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(
                  review.response != null ? 'Edit Response' : 'Respond',
                  style: const TextStyle(fontSize: 12),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final filters = [
      {'id': 'all', 'label': 'All'},
      {'id': '5', 'label': '5 Stars'},
      {'id': '4', 'label': '4 Stars'},
      {'id': 'responded', 'label': 'Responded'},
      {'id': 'pending', 'label': 'Pending'},
    ];

    return Container(
      color: Colors.white,
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (_) => onFilterChanged(filter['id']!),
              selectedColor: Colors.amber,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 60;
  @override
  double get minExtent => 60;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
