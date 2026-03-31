import 'package:flutter/material.dart';
import '../services/home_screen.dart';
import '../bookings/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const BookingsScreen(),
    const ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey<int>(_index), // Required for AnimatedSwitcher to recognize change
          child: screens[_index],
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
          height: 70, // Explicit height for the row content
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _navItem(0, Icons.home_rounded, 'HOME'),
              _navItem(1, Icons.calendar_month_rounded, 'BOOKING'),
              _navItem(2, Icons.chat_rounded, 'CHAT'),
              _navItem(3, Icons.person_rounded, 'PROFILE'),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(isActive ? 12 : 0),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFFF6B00) : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade600,
              size: isActive ? 26 : 28,
            ),
          ),
          if (!isActive) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
