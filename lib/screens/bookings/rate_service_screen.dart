import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  final List<File> _selectedImages = [];
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
        _selectedImages.add(File(image.path));
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
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSummaryCard(serviceName, providerName, date),
            const SizedBox(height: 32),
            Text(
              'How was your experience?',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F212C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps $providerName and our community maintain high standards.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildStarRating(),
            const SizedBox(height: 24),
            _buildTags(),
            const SizedBox(height: 32),
            _buildReviewInput(providerName),
            const SizedBox(height: 32),
            _buildPhotoSection(),
            const SizedBox(height: 48),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String serviceName, String providerName, String date) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1540569014015-19a7ee504e3a?q=80&w=200&auto=format&fit=crop'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                child: const Icon(Icons.shield, color: Colors.white, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SERVICE COMPLETED',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF6B00),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            serviceName,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF1F212C)),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade600),
              children: [
                const TextSpan(text: 'Performed by '),
                TextSpan(
                  text: providerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F212C)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoChip(Icons.calendar_today, date),
              const SizedBox(width: 12),
              _infoChip(Icons.access_time, '45 mins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
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
              size: 48,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              tag,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _reviewController,
                maxLines: 4,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Describe your experience with $providerName and the quality of the repair...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 15),
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
              width: 140,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  Text(
                    'ADD PHOTO',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade600,
                      letterSpacing: 1,
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
                    borderRadius: BorderRadius.circular(25),
                    child: Image.file(
                      _selectedImages[index],
                      height: 100,
                      width: 140,
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

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReviewSuccessScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Submit Review',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
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
                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF1F212C)),
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
                child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
