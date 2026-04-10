import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_service_screen.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryIndigo = const Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(String serviceId, bool currentValue) async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .update({'isActive': !currentValue});
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Service?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'This action cannot be undone. The service will be permanently removed.',
          style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service deleted.',
                style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopFrame(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildServiceList(null),
                _buildServiceList(true),
                _buildServiceList(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFrame() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryIndigo,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              "My Services",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildTabBarContent(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: primaryIndigo,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
          labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(height: 36, text: 'All'),
            Tab(height: 36, text: 'Active'),
            Tab(height: 36, text: 'Inactive'),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceList(bool? isActive) {
    return _ServiceListContent(
      isActive: isActive,
      primaryIndigo: primaryIndigo,
      toggleActive: _toggleActive,
      deleteService: _deleteService,
    );
  }
}

class _ServiceListContent extends StatefulWidget {
  final bool? isActive;
  final Color primaryIndigo;
  final Function(String, bool) toggleActive;
  final Function(String) deleteService;

  const _ServiceListContent({
    required this.isActive,
    required this.primaryIndigo,
    required this.toggleActive,
    required this.deleteService,
  });

  @override
  State<_ServiceListContent> createState() => _ServiceListContentState();
}

class _ServiceListContentState extends State<_ServiceListContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Stream<List<Map<String, dynamic>>> _getServicesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    Query query = FirebaseFirestore.instance
        .collection('services')
        .where('providerId', isEqualTo: user.uid);

    if (widget.isActive != null) {
      query = query.where('isActive', isEqualTo: widget.isActive);
    }

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      docs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getServicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Query error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(widget.isActive);
        }

        final services = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) => _buildServiceCard(services[index]),
        );
      },
    );
  }

  Widget _buildEmptyState(bool? isActive) {
    String message;
    IconData icon;
    if (isActive == null) {
      message =
          "You haven't published any services yet.\nTap + to create your first listing.";
      icon = Icons.storefront_outlined;
    } else if (isActive) {
      message =
          "No active services.\nActivate a service to make it visible to customers.";
      icon = Icons.toggle_off_outlined;
    } else {
      message = "No inactive services.";
      icon = Icons.check_circle_outline;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.primaryIndigo.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 48, color: widget.primaryIndigo.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.grey.shade500,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String serviceId = service['id'] ?? '';
    final bool isActive = service['isActive'] ?? false;
    final String title = service['title'] ?? 'Untitled Service';
    final String category = service['category'] ?? '';
    final String subCategory = category.contains('>')
        ? category.split('>').last.trim()
        : category;
    final String price = service['price'] ?? '0';
    final String priceType = service['priceType'] ?? 'per hour';
    final String? imageUrl = service['servicePhotoUrl'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? widget.primaryIndigo.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 76,
                height: 76,
                color: const Color(0xFFF1F5F9),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey.shade400,
                          size: 28,
                        ),
                      )
                    : Icon(
                        Icons.home_repair_service_rounded,
                        color: widget.primaryIndigo.withValues(alpha: 0.4),
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditServiceScreen(
                                serviceData: service,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.note_alt_outlined,
                            size: 22,
                            color: widget.primaryIndigo.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (subCategory.isNotEmpty)
                    Text(
                      subCategory,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'RM $price / $priceType',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.primaryIndigo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? const Color(0xFF166534)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 🔹 TOGGLE SWITCH (Now at bottom)
                      GestureDetector(
                        onTap: () => widget.toggleActive(serviceId, isActive),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 22,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isActive
                                ? const Color(0xFFDCFCE7)
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF16A34A)
                                      .withValues(alpha: 0.2)
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: isActive
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey.shade400,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
