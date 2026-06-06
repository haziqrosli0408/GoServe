import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_screen.dart';
import '../bookings/bookings_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/presence_service.dart';
import '../chat/ai_chat_screen.dart';

class CustomerHome extends StatefulWidget {
  final int initialIndex;
  const CustomerHome({super.key, this.initialIndex = 0});

  static void setIndex(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_CustomerHomeState>();
    state?.updateIndex(index);
  }

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _index;
  bool _showStatusBarCover = false;

  void updateIndex(int index) {
    setState(() {
      _index = index;
    });
  }

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

  final List<Widget> screens = [
    const HomeScreen(),
    const BookingsScreen(),
    const SizedBox.shrink(), // Placeholder for AI center button
    const ChatScreen(themeColor: Color(0xFFFF6B00)),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Detect scroll distance to toggle status bar cover, but only for vertical scrolls
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.metrics.pixels > 30) {
              if (!_showStatusBarCover) setState(() => _showStatusBarCover = true);
            } else {
              if (_showStatusBarCover) setState(() => _showStatusBarCover = false);
            }
          }
          return false;
        },
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_index), // Required for AnimatedSwitcher to recognize change
                child: screens[_index],
              ),
            ),
            // 🔹 ANIMATED STATUS BAR COVER (Visible only when scrolling)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showStatusBarCover ? 1.0 : 0.0,
                child: Container(
                  height: MediaQuery.of(context).padding.top,
                  color: _index == 1 ? const Color(0xFFFF6B00) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 🔹 APP BAR (Displays only on Services Tab)
  PreferredSizeWidget? _buildAppBar() {
    return null; // All screens now manage their own AppBars or don't need this one
  }

  // 🔹 CUSTOM PREMIUM BOTTOM NAV BAR
  Widget _buildBottomNav() {
    return SizedBox(
      height: 75 + MediaQuery.of(context).padding.bottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // White Nav Bar
          Container(
            height: 75 + MediaQuery.of(context).padding.bottom,
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
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _navItem(0, Icons.home_rounded, 'Home'),
                    _navItem(1, Icons.calendar_month_rounded, 'Bookings'),
                    const SizedBox(width: 50), // Space for floating button
                    _navItem(3, Icons.chat_bubble_outline_rounded, 'Chat'),
                    _navItem(4, Icons.person_rounded, 'Profile'),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
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
                color: isActive ? const Color(0xFFFF6B00) : Colors.grey.shade500,
                size: 26,
              ),
              if (index == 3) _buildChatBadge(isActive),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFFFF6B00) : Colors.grey.shade500,
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
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
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
}
