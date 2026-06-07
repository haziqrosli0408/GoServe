import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../dashboards/customer_home.dart';

class RateServiceScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const RateServiceScreen({super.key, required this.bookingData});

  @override
  State<RateServiceScreen> createState() => _RateServiceScreenState();
}

class _RateServiceScreenState extends State<RateServiceScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  final List<String> _tags = [
    'Punctual',
    'Professional',
    'Clear Communication',
    'Clean Workspace'
  ];

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String serviceName = widget.bookingData['serviceName'] ?? 'Kitchen Sink Repair';
    final String providerName = widget.bookingData['providerName'] ?? 'Alex J.';
    final String date = widget.bookingData['date'] ?? 'Oct 24, 2023';
    final String photoUrl = widget.bookingData['providerProfileUrl'] ?? widget.bookingData['profileUrl'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rate Service',
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSummaryCard(serviceName, providerName, date, photoUrl),
            const SizedBox(height: 20),
            Text(
              'How was your experience?',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F212C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your feedback helps $providerName and our community maintain high standards.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            _buildStarRating(),
            const SizedBox(height: 16),
            _buildTags(),
            const SizedBox(height: 20),
            _buildReviewInput(providerName),
            const SizedBox(height: 20),
            _buildPhotoSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String serviceName, String providerName, String date, String photoUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFFE2E8F0),
                          child: Center(
                            child: Text(
                              providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                              style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 24, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: const Color(0xFFE2E8F0),
                        child: Center(
                          child: Text(
                            providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                            style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                child: const Icon(Icons.shield, color: Colors.white, size: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SERVICE COMPLETED',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF6B00),
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            serviceName,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
              children: [
                const TextSpan(text: 'Performed by '),
                TextSpan(
                  text: providerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F212C)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoChip(Icons.calendar_today, date),
              const SizedBox(width: 8),
              _infoChip(Icons.access_time, '45 mins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => setState(() => _rating = index + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              index < _rating ? Icons.star_rounded : Icons.star_rounded,
              size: 36,
              color: index < _rating ? const Color(0xFFFF6B00) : Colors.grey.shade200,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _tags.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedTags.remove(tag);
              } else {
                _selectedTags.add(tag);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              tag,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewInput(String providerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Write a Review (Optional)',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _reviewController,
                maxLines: 3,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Describe your experience with $providerName...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
              Text(
                '${_reviewController.text.length} / 500',
                style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ADD PHOTO BUTTON
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 100,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    'ADD PHOTO',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // SELECTED IMAGES
          ...List.generate(_selectedImages.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: kIsWeb
                      ? Image.network(
                          _selectedImages[index].path,
                          height: 70,
                          width: 100,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(_selectedImages[index].path),
                          height: 70,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Upload Images to Storage
      List<String> imageUrls = [];
      for (var imageFile in _selectedImages) {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
        Reference ref = FirebaseStorage.instance.ref().child('reviews').child(fileName);
        
        if (kIsWeb) {
          final bytes = await imageFile.readAsBytes();
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putFile(File(imageFile.path));
        }
        
        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // 2. Prepare Review Data
      final reviewData = {
        'userId': user.uid,
        'userName': user.displayName ?? 'Customer',
        'userProfileUrl': user.photoURL ?? '',
        'providerId': widget.bookingData['providerId'],
        'serviceId': widget.bookingData['serviceId'],
        'serviceName': widget.bookingData['serviceName'],
        'bookingId': widget.bookingData['id'],
        'orderId': widget.bookingData['orderId'],
        'rating': _rating,
        'comment': _reviewController.text.trim(),
        'tags': _selectedTags,
        'images': imageUrls,
        'status': 'Pending', // Matches Admin Dashboard capitalized convention
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 3. Save to Global Reviews Collection
      await FirebaseFirestore.instance.collection('reviews').add(reviewData);

      // 4. Also update the booking as 'rated' so they don't rate twice
      if (widget.bookingData['id'] != null) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingData['id'])
            .update({'isRated': true});
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ReviewSuccessScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error submitting review: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitReview,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: _isSubmitting ? Colors.grey : const Color(0xFFFF6B00),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: _isSubmitting 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                'Submit Review',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
        ),
      ),
    );
  }
}

class ReviewSuccessScreen extends StatelessWidget {
  const ReviewSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: Color(0xFFFDF0E6), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Color(0xFFFF6B00), size: 64),
              ),
              const SizedBox(height: 32),
              Text(
                'Review Submitted!',
                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w600, color: const Color(0xFF1F212C)),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for your feedback. We appreciate your contribution to our community!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation1, animation2) => const CustomerHome(initialIndex: 1),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
