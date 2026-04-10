import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_service_screen.dart';
import 'dart:io';

class ServiceSelector {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const ServiceSelectorModal(),
    );
  }
}

class ServiceSelectorModal extends StatefulWidget {
  const ServiceSelectorModal({super.key});

  @override
  State<ServiceSelectorModal> createState() => _ServiceSelectorModalState();
}

class _ServiceSelectorModalState extends State<ServiceSelectorModal> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black, size: 30),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Service',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Setup your professional services listings',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: AddServiceScreen.getDraftsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
              final drafts = snapshot.data!;
              
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'IN-PROGRESS DRAFTS (${drafts.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isEditMode = !_isEditMode),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _isEditMode ? 'Done' : 'Select',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isEditMode ? Colors.redAccent : const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) => _buildDraftCard(context, drafts[index], index),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            }
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddServiceScreen(startNew: true)),
                );
              },
              child: Column(
                children: [
                   Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create Your New Service Listing',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildDraftCard(BuildContext context, Map<String, dynamic> draft, int index) {
    final File? mainImage = draft['mainImage'];
    final String title = draft['title']?.toString() ?? '';
    final String categoryPath = draft['category']?.toString() ?? '';
    final String category = categoryPath.split('>').last.trim().isEmpty 
        ? (categoryPath.split('>').first.trim().isEmpty ? 'Uncategorized' : categoryPath.split('>').first.trim())
        : categoryPath.split('>').last.trim();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  image: mainImage != null 
                    ? DecorationImage(image: FileImage(mainImage), fit: BoxFit.cover) 
                    : null,
                ),
                child: mainImage == null 
                  ? Icon(Icons.image_not_supported_rounded, color: Colors.grey.shade300, size: 28) 
                  : null,
              ),
              if (_isEditMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () async {
                      final String? draftId = draft['id'];
                      if (draftId != null) {
                        await AddServiceScreen.clearDraft(draftId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DRAFT #${index + 1}',
                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled Service' : title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddServiceScreen(initialDraftData: draft)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Resume',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
