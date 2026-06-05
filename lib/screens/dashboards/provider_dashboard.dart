import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './provider_home_screen.dart';
import '../provider/provider_bookings_screen.dart';
import '../provider/my_services_screen.dart';
import '../chat/chat_screen.dart';
import '../provider/service_selector.dart';
import '../provider/verification_screen.dart';
import '../../services/presence_service.dart';

class ProviderDashboard extends StatefulWidget {
  final int initialIndex;
  const ProviderDashboard({super.key, this.initialIndex = 0});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    PresenceService.updatePresence(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PresenceService.updatePresence(true);
    } else {
      PresenceService.updatePresence(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const ProviderHomeScreen(),
      const ProviderBookingsScreen(),
      const SizedBox.shrink(), // Placeholder for center button
      const MyServicesScreen(),
      const ChatScreen(themeColor: Color(0xFF4F46E5)),
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
    return SizedBox(
      height: 65 + MediaQuery.of(context).padding.bottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // White Nav Bar
          Container(
            height: 65 + MediaQuery.of(context).padding.bottom,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
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
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _navItem(0, Icons.home_rounded, 'Home'),
                    _navItem(1, Icons.calendar_month_rounded, 'Bookings'),
                    const SizedBox(width: 50), // Space for floating button
                    _navItem(3, Icons.storefront_rounded, 'Jobs'),
                    _navItem(4, Icons.chat_bubble_outline_rounded, 'Chat'),
                  ],
                ),
              ),
            ),
          ),
          // Floating Center Button
          Positioned(
            top: -25,
            child: _buildCenterButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
          final status = doc.data()?['verificationStatus'] ?? 'none';

          if (status == 'verified') {
            if (mounted) ServiceSelector.show(context);
          } else {
            if (mounted) _showVerificationPopup(context, status);
          }
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _index == index;

    return GestureDetector(
      onTap: () {
        setState(() => _index = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade500,
                size: 26,
              ),
              if (index == 4) _buildChatBadge(isActive),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBadge(bool isActive) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        int totalUnread = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalUnread += (data['unreadCount']?[currentUser.uid] ?? 0) as int;
        }

        if (totalUnread == 0) return const SizedBox.shrink();

        return Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00), // Always orange as requested
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white, 
                width: 1.5
              ),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              totalUnread > 99 ? '99+' : totalUnread.toString(),
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 8, 
                fontWeight: FontWeight.w600
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
  void _showVerificationPopup(BuildContext context, String status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: status == 'pending' ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'pending' ? Icons.hourglass_empty_rounded : Icons.verified_user_rounded,
                color: status == 'pending' ? Colors.orange : const Color(0xFF4F46E5),
                size: 30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              status == 'pending' ? 'Verification Pending' : 'Get Verified First',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              status == 'pending' 
                ? 'Our team is reviewing your documents. You will be able to add services once approved.'
                : 'To ensure platform safety, you must complete your identity verification before listing services.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (status != 'pending')
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const VerificationScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Start Verification', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
