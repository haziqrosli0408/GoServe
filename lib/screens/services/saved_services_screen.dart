import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_details.dart';

class SavedServicesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> savedProviders;
  
  const SavedServicesScreen({super.key, required this.savedProviders});

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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Saved Services',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1B1B1B),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          Expanded(
            child: savedProviders.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.68, // Give enough vertical space for the text lines below the image
                    ),
                    itemCount: savedProviders.length,
                    itemBuilder: (context, index) {
                      return _buildSavedCard(context, savedProviders[index]);
                    },
                  ),
          ),
        ],
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
    String name = provider['name'] ?? 'Elite Home Services';
    List<dynamic> svcs = provider['services'] ?? [];
    String sub = svcs.isNotEmpty ? svcs.first.toString() : 'Expert Professional';
    String price = provider['price']?.toString() ?? '85';
    String rating = '4.9';
    String profileUrl = provider['profileUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: provider)));
      },
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: profileUrl.isNotEmpty ? Image.network(
                  profileUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network('https://i.pravatar.cc/150?u=$name', width: double.infinity, fit: BoxFit.cover),
                ) : Image.network(
                  'https://i.pravatar.cc/150?u=$name',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // Row 1: Title and Bookmark Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sub, // Service name
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(                   
                  Icons.bookmark, // Hardcoded active for this page
                  size: 20,
                  color: Colors.black,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Price and Rating
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
                        text: 'RM$price/hr',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF6B00),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ' · ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
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

            // Row 3: Provider Profile and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundImage: profileUrl.isNotEmpty
                    ? NetworkImage(profileUrl)
                    : NetworkImage('https://i.pravatar.cc/150?u=$name') as ImageProvider,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
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
