import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/home_screen.dart';
import '../bookings/bookings_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

class CustomerHome extends StatefulWidget {
  final int initialIndex;
  const CustomerHome({super.key, this.initialIndex = 0});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome>
    with SingleTickerProviderStateMixin {
  late int _index;
  bool _showStatusBarCover = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  final List<Widget> screens = [
    const HomeScreen(),
    const BookingsScreen(),
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
    return Container(
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
        child: Container(
          height: 65, // Explicit height for the row content
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.calendar_month_rounded, 'Bookings'),
              _navItem(2, Icons.chat_rounded, 'Chat'),
              _navItem(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _index == index;

    return GestureDetector(
      onTap: () => setState(() => _index = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFFFF6B00) : Colors.grey.shade600,
                size: 28,
              ),
              if (index == 2) _buildChatBadge(isActive),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? const Color(0xFFFF6B00) : Colors.grey.shade600,
              letterSpacing: 0.5,
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
