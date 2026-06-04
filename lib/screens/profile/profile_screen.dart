import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/saved_services_screen.dart';
import '../../widgets/skeleton_box.dart';
import 'provider_bookings_history.dart';
import 'provider_reviews.dart';
import 'provider_earnings_page.dart';
import 'settings_page.dart';
import '../services/service_details.dart';
import '../provider/edit_service_screen.dart';
import '../provider/service_analytics_screen.dart';
import 'customer_reviews_page.dart';

class ProfileScreen extends StatefulWidget {
  final Color themeColor;
  const ProfileScreen({super.key, this.themeColor = const Color(0xFFFF6B00)});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  int bookingsCount = 0;
  int reviewsCount = 0;
  double earnings = 0.0;
  double rating = 0.0;
  int savedCount = 0;
  String? role;
  List<Map<String, dynamic>> _services = [];
  bool _isServicesLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (user == null) return;

    // 1. Fetch Basic Info & Role
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
    DocumentSnapshot providerDoc =
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(user!.uid)
            .get();

    // Determine if they are actually an active provider (must have a customId)
    final bool hasProviderRecord =
        providerDoc.exists &&
        (providerDoc.data() as Map<String, dynamic>)['customId'] != null;

    if (hasProviderRecord) {
      role = 'provider';
      final pData = providerDoc.data() as Map<String, dynamic>;
      final uData =
          userDoc.exists ? userDoc.data() as Map<String, dynamic> : {};

      setState(() {
        userData = {...uData, ...pData};
        rating = (userData!['rating']?.toDouble() ?? 0.0);
        earnings =
            double.tryParse(userData!['earnings']?.toString() ?? '0') ?? 0.0;
        savedCount = (userData!['savedServices'] as List?)?.length ?? 0;
      });
    } else if (userDoc.exists) {
      role = 'customer';
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>;
        savedCount = (userData!['savedServices'] as List?)?.length ?? 0;
      });
    } else {
      return;
    }

    // 2. Fetch Real Booking Count
    FirebaseFirestore.instance
        .collection('bookings')
        .where(
          role == 'customer' ? 'customerId' : 'providerId',
          isEqualTo: user!.uid,
        )
        .get()
        .then((snapshot) {
          if (mounted) {
            setState(() {
              bookingsCount = snapshot.size;
            });
          }
        });

    // 3. Fetch Real Reviews Count (For Customers) OR Real Rating (For Providers)
    if (role == 'customer') {
      FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'Approved')
          .get()
          .then((snapshot) {
            if (mounted) {
              setState(() {
                reviewsCount = snapshot.size;
              });
            }
          });
    } else {
      // Calculate Real Rating for Provider
      FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'Approved')
          .get()
          .then((snapshot) {
            if (snapshot.docs.isNotEmpty && mounted) {
              double totalRating = 0;
              for (var rDoc in snapshot.docs) {
                totalRating += (rDoc.data()['rating'] as num).toDouble();
              }
              setState(() {
                rating = totalRating / snapshot.docs.length;
              });
            }
          });

      // Calculate Real Earnings for Provider (Available Balance = Completed bookings - Withdrawals)
      Future.wait([
        FirebaseFirestore.instance
            .collection('bookings')
            .where('providerId', isEqualTo: user!.uid)
            .where('status', isEqualTo: 'Completed')
            .get(),
        FirebaseFirestore.instance
            .collection('withdrawals')
            .where('providerId', isEqualTo: user!.uid)
            .get(),
      ]).then((results) {
        if (mounted) {
          final bookingsSnapshot = results[0];
          final withdrawalsSnapshot = results[1];

          double totalCompleted = 0.0;
          for (var bDoc in bookingsSnapshot.docs) {
            final bData = bDoc.data();
            if (bData['payoutStatus'] == 'transferred') {
              final priceStr = bData['totalPrice'] ?? bData['price'] ?? '0';
              final cleanPrice =
                  priceStr.toString().replaceAll('RM', '').trim();
              totalCompleted += double.tryParse(cleanPrice) ?? 0.0;
            }
          }

          double totalWithdrawn = 0.0;
          for (var wDoc in withdrawalsSnapshot.docs) {
            final wData = wDoc.data();
            final amount = (wData['amount'] as num?)?.toDouble() ?? 0.0;
            totalWithdrawn += amount;
          }

          setState(() {
            earnings = totalCompleted - totalWithdrawn;
          });
        }
      });
    }

    if (role != null) {
      _fetchServices(role!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          userData == null
              ? _buildSkeletonLoader()
              : CustomScrollView(
                slivers: [
                  // 🔹 HEADER WITH TITLE & CURVED SHEET
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 280,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.themeColor,
                                widget.themeColor.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                        // 🔹 HEADER BUTTONS (ABOVE PICTURE)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 10,
                          left: 10,
                          right: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (role == 'provider')
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                )
                              else
                                const SizedBox(width: 48),
                              IconButton(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SettingsPage(
                                        themeColor: widget.themeColor,
                                        role: role ?? 'customer',
                                      ),
                                    ),
                                  ).then((_) => fetchUserData());
                                },
                              ),
                            ],
                          ),
                        ),
                        // 🔹 CURVED WHITE BACKGROUND SHEET
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                          ),
                        ),
                        // 🔹 PROFILE IMAGE
                        Positioned(
                          bottom: 0,
                          left: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage:
                                  (userData!['profileUrl'] != null &&
                                          userData!['profileUrl']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(userData!['profileUrl'])
                                      : null,
                              child:
                                  (userData!['profileUrl'] == null ||
                                          userData!['profileUrl']
                                              .toString()
                                              .isEmpty)
                                      ? Text(
                                        (userData!['name'] ?? 'U')[0]
                                            .toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w600,
                                          color: widget.themeColor,
                                        ),
                                      )
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔹 PROFILE INFO & STATS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData!['name'] ?? 'User Name',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userData!['email'] ?? 'email@example.com',
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey.shade500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _showEditProfile(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: widget.themeColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Edit Profile",
                                        style: GoogleFonts.outfit(
                                          color: widget.themeColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileStat(
                                  icon: Icons.calendar_today_outlined,
                                  value: bookingsCount.toString(),
                                  label: 'Bookings',
                                  themeColor: widget.themeColor,
                                  onTap: role == 'provider'
                                      ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ProviderBookingsHistoryPage(),
                                            ),
                                          )
                                      : null,
                                ),
                              ),
                              if (role == 'provider') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ProfileStat(
                                    icon: Icons.star_outline_rounded,
                                    value: rating.toStringAsFixed(1),
                                    label: 'Rating',
                                    themeColor: widget.themeColor,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ProviderReviewsPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (role == 'customer') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ProfileStat(
                                    icon: Icons.rate_review_outlined,
                                    value: reviewsCount.toString(),
                                    label: 'Reviews',
                                    themeColor: widget.themeColor,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomerReviewsPage(
                                          themeColor: widget.themeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ProfileStat(
                                  icon:
                                      role == 'provider'
                                          ? Icons.payments_outlined
                                          : Icons.bookmark_outline_rounded,
                                  value:
                                      role == 'provider'
                                          ? 'RM ${earnings.toStringAsFixed(0)}'
                                          : savedCount.toString(),
                                  label:
                                      role == 'provider' ? 'Earnings' : 'Saved',
                                  themeColor: widget.themeColor,
                                  onTap: role == 'customer'
                                      ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const SavedServicesScreen(),
                                            ),
                                          )
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ProviderEarningsPage(),
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                  ),

                  // 🔹 SERVICES GRID SECTION (Pair Layout)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Text(
                        role == 'provider' ? 'My Services' : 'Saved Services',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  if (_isServicesLoading)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else if (_services.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 20,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                role == 'provider'
                                    ? Icons.storefront_outlined
                                    : Icons.bookmark_outline,
                                size: 40,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                role == 'provider'
                                    ? 'No services published yet'
                                    : 'No saved services yet',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildGridServiceCard(
                              context,
                              _services[index],
                            );
                          },
                          childCount: _services.length,
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Future<void> _fetchServices(String userRole) async {
    if (user == null) return;
    try {
      if (userRole == 'customer') {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        final List<dynamic> savedIds = userDoc.data()?['savedServices'] ?? [];

        if (savedIds.isEmpty) {
          if (mounted) {
            setState(() {
              _services = [];
              _isServicesLoading = false;
            });
          }
          return;
        }

        final snapshot = await FirebaseFirestore.instance
            .collection('services')
            .where('isActive', isEqualTo: true)
            .get();

        final allServices = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        final filtered = allServices
            .where((s) => savedIds.contains(s['serviceId']))
            .toList();

        if (mounted) {
          setState(() {
            _services = filtered.cast<Map<String, dynamic>>();
            _isServicesLoading = false;
          });
        }
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('services')
            .where('providerId', isEqualTo: user!.uid)
            .get();

        final providerServices = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        if (mounted) {
          setState(() {
            _services = providerServices.cast<Map<String, dynamic>>();
            _isServicesLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
      if (mounted) {
        setState(() => _isServicesLoading = false);
      }
    }
  }

  Future<void> _toggleUnsave(String serviceId) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'savedServices': FieldValue.arrayRemove([serviceId]),
      });
      setState(() {
        savedCount = (savedCount - 1).clamp(0, 9999);
      });
      _fetchServices('customer');
    } catch (e) {
      debugPrint("Error unsaving service: $e");
    }
  }

  Widget _buildGridServiceCard(
    BuildContext context,
    Map<String, dynamic> service,
  ) {
    final isProvider = role == 'provider';
    String serviceId = service['serviceId'] ?? service['id'] ?? '';
    String providerName = service['providerName'] ??
        service['name'] ??
        userData?['name'] ??
        'Elite Pro';
    String title = service['title'] ?? 'Elite Service';
    String price = service['price']?.toString() ?? '0';
    double avgRating =
        double.tryParse(service['rating']?.toString() ?? '0') ?? 0.0;
    String ratingText = avgRating > 0 ? avgRating.toStringAsFixed(1) : 'New';
    String providerProfileUrl = service['providerProfileUrl'] ??
        service['profileUrl'] ??
        userData?['profileUrl'] ??
        '';
    String servicePhotoUrl = service['servicePhotoUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        if (isProvider) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceAnalyticsScreen(serviceData: service),
            ),
          ).then((_) => fetchUserData());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailsScreen(provider: service),
            ),
          ).then((_) => fetchUserData());
        }
      },
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: servicePhotoUrl.isNotEmpty
                    ? Image.network(
                        servicePhotoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.network(
                          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.network(
                        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isProvider)
                  GestureDetector(
                    onTap: () => _toggleUnsave(serviceId),
                    child: Icon(
                      Icons.bookmark,
                      size: 20,
                      color: widget.themeColor,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditServiceScreen(serviceData: service),
                        ),
                      ).then((_) => fetchUserData());
                    },
                    child: Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: widget.themeColor.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ' · ',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 4),
                Text(
                  ratingText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: providerProfileUrl.isNotEmpty
                      ? NetworkImage(providerProfileUrl)
                      : null,
                  child: providerProfileUrl.isEmpty
                      ? Text(
                          providerName.isNotEmpty
                              ? providerName[0].toUpperCase()
                              : 'P',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1F212C),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    providerName,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
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

  // 📌 NAVIGATE TO EDIT PROFILE SCREEN
  void _showEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              userData: userData!,
              themeColor: widget.themeColor,
              onSave: fetchUserData,
            ),
      ),
    );
  }


  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Stack(
            children: [
              SkeletonBox(
                width: double.infinity,
                height: 280,
                color: widget.themeColor.withValues(alpha: 0.1),
              ),
              Positioned(
                bottom: 0,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const SkeletonBox(
                    width: 120,
                    height: 120,
                    isCircle: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 200, height: 24),
                const SizedBox(height: 8),
                const SkeletonBox(width: 150, height: 16),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 80,
                        borderRadiusValue: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 80,
                        borderRadiusValue: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 80,
                        borderRadiusValue: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const SkeletonBox(width: 120, height: 18),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  itemBuilder:
                      (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SkeletonBox(
                          width: double.infinity,
                          height: 50,
                          borderRadiusValue: 12,
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

// 📌 FULL PAGE EDIT PROFILE SCREEN
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Color themeColor;
  final VoidCallback onSave;

  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.themeColor,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  final user = FirebaseAuth.instance.currentUser;

  File? _image;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    emailController = TextEditingController(
      text: widget.userData['email'] ?? '',
    );
    phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.themeColor.withValues(alpha: 0.1),
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage:
                          _image != null
                              ? FileImage(_image!)
                              : (widget.userData['profileUrl'] != null &&
                                  widget.userData['profileUrl']
                                      .toString()
                                      .isNotEmpty)
                              ? NetworkImage(widget.userData['profileUrl'])
                              : null,
                      child:
                          isUploading
                              ? CircularProgressIndicator(
                                color: widget.themeColor,
                              )
                              : (_image == null &&
                                  (widget.userData['profileUrl'] == null ||
                                      widget.userData['profileUrl']
                                          .toString()
                                          .isEmpty))
                              ? Text(
                                (widget.userData['name'] ?? 'U')[0]
                                    .toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w600,
                                  color: widget.themeColor,
                                ),
                              )
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.themeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _pickImage,
                child: Text(
                  "Change Photo",
                  style: GoogleFonts.outfit(
                    color: widget.themeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildEditField(
              "Full Name",
              nameController,
              Icons.person_outline,
              widget.themeColor,
            ),
            _buildEditField(
              "Email Address",
              emailController,
              Icons.email_outlined,
              widget.themeColor,
            ),
            _buildEditField(
              "Phone Number",
              phoneController,
              Icons.phone_outlined,
              widget.themeColor,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  isUploading
                      ? null
                      : () async {
                        setState(() {
                          isUploading = true;
                        });

                        try {
                          String? profileUrl = widget.userData['profileUrl'];

                          if (_image != null) {
                            final ref = FirebaseStorage.instance
                                .ref()
                                .child('profile_pics')
                                .child('${user!.uid}.jpg');

                            await ref.putFile(_image!);
                            profileUrl = await ref.getDownloadURL();
                          }

                          await FirebaseFirestore.instance
                              .collection(
                                widget.userData['role'] == 'provider'
                                    ? "providers"
                                    : "users",
                              )
                              .doc(user!.uid)
                              .update({
                                "name": nameController.text.trim(),
                                "email": emailController.text.trim(),
                                "phone": phoneController.text.trim(),
                                if (profileUrl != null)
                                  "profileUrl": profileUrl,
                              });

                          widget.onSave();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          setState(() {
                            isUploading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error updating profile: $e"),
                            ),
                          );
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  isUploading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        "Save Changes",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildEditField(
  String label,
  TextEditingController controller,
  IconData icon,
  Color themeColor,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        TextField(
          controller: controller,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: themeColor, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 35),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

// Small reusable components
class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color themeColor;
  final VoidCallback? onTap;

  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.themeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: themeColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


