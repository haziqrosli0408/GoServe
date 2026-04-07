import 'dart:io';
import 'package:flutter/material.dart';
import './provider_home_screen.dart';
import '../provider/provider_bookings_screen.dart';
import '../provider/my_services_screen.dart';
import '../chat/chat_screen.dart';
import '../provider/add_service_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProviderDashboard extends StatefulWidget {
  final int initialIndex;
  const ProviderDashboard({super.key, this.initialIndex = 0});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard>
    with SingleTickerProviderStateMixin {
  late int _index;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const ProviderHomeScreen(),
      const ProviderBookingsScreen(),
      const SizedBox.shrink(), // Placeholder for center button
      const MyServicesScreen(),
      const ChatScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey<int>(_index),
          child: screens[_index],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.calendar_month_rounded, 'Bookings'),
              _navItem(2, Icons.add_rounded, 'Add'),
              _navItem(3, Icons.storefront_rounded, 'Services'),
              _navItem(4, Icons.chat_rounded, 'Chat'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _index == index;
    bool isCenter = index == 2;

    return GestureDetector(
      onTap: () {
        if (isCenter) {
          _showAddServiceSheet(context);
        } else {
          setState(() => _index = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(isCenter ? 12 : 0),
            decoration: BoxDecoration(
              color: isCenter ? const Color(0xFF4F46E5) : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isCenter ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Icon(
              icon,
              color: isCenter ? Colors.white : (isActive ? const Color(0xFF4F46E5) : Colors.grey.shade600),
              size: 28,
            ),
          ),
          if (!isCenter) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddServiceSheet(BuildContext dashboardContext) {
    setState(() => _isEditMode = false); // Reset when opening
    showModalBottomSheet(
      context: dashboardContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext builderContext, StateSetter setModalState) {
          return _buildDraftSelectionModal(builderContext, setModalState);
        },
      ),
    );
  }

  Widget _buildDraftSelectionModal(BuildContext context, StateSetter setModalState) {
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
                    fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(() => _isEditMode = !_isEditMode),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _isEditMode ? 'Done' : 'Select',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
                      itemBuilder: (context, index) => _buildDraftCard(context, drafts[index], index, setModalState),
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
                // Clicking "Create New Service" should start fresh but preserve old draft
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
                      fontWeight: FontWeight.bold,
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

  Widget _buildDraftCard(BuildContext context, Map<String, dynamic> draft, int index, StateSetter setModalState) {
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
                      setModalState(() {
                        // The stream will update automatically, 
                        // but we might want to exit edit mode if last item
                      });
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
                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
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
                    fontWeight: FontWeight.bold,
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
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
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
