import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './provider_home_screen.dart';
import '../provider/provider_bookings_screen.dart';
import '../provider/my_services_screen.dart';
import '../chat/chat_screen.dart';
import '../provider/service_selector.dart';

class ProviderDashboard extends StatefulWidget {
  final int initialIndex;
  const ProviderDashboard({super.key, this.initialIndex = 0});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard>
    with SingleTickerProviderStateMixin {
  late int _index;

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
          ServiceSelector.show(context);
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isCenter ? Colors.white : (isActive ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                  size: 28,
                ),
                if (index == 4) _buildChatBadge(isActive),
              ],
            ),
          ),
          if (!isCenter) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
}
