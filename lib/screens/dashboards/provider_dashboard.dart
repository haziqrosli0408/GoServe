import 'package:flutter/material.dart';
import 'dart:async';
import '../profile/settings_modal.dart';
import '../chat/chat_screen.dart';
import '../services/add_service.dart';
import '../profile/provider_reviews.dart'; // Ensure this file exists

enum BookingStatus { pending, confirmed, completed, cancelled }

class BookingData {
  int id;
  String name;
  String service;
  String date;
  String time;
  BookingStatus status;
  String price;
  String location;
  String avatar;

  BookingData({
    required this.id,
    required this.name,
    required this.service,
    required this.date,
    required this.time,
    required this.status,
    required this.price,
    required this.location,
    required this.avatar,
  });
}

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  bool _isHouseCleaningActive = true;
  String _filterStatus = 'all';
  bool showSuccessMessage = false;
  String successMessage = '';

  late List<BookingData> _allBookings;

  @override
  void initState() {
    super.initState();
    _allBookings = [
      BookingData(
        id: 1,
        name: "Alia",
        service: "Deep House Cleaning",
        date: "Dec 28, 2024",
        time: "10:00 AM",
        status: BookingStatus.confirmed,
        price: "85",
        location: "123 Main Street, Apartment 4B",
        avatar: "https://ui-avatars.com/api/?name=John+Smith&background=random",
      ),
      BookingData(
        id: 2,
        name: "Hanim",
        service: "Office Cleaning",
        date: "Dec 29, 2024",
        time: "02:00 PM",
        status: BookingStatus.pending,
        price: "120",
        location: "Cyberjaya, Sepang",
        avatar:
            "https://ui-avatars.com/api/?name=Emma+Wilson&background=random",
      ),
    ];
  }

  List<BookingData> get _filteredBookings {
    if (_filterStatus == 'all') return _allBookings;
    return _allBookings.where((b) => b.status.name == _filterStatus).toList();
  }

  void showSuccess(String message) {
    setState(() {
      successMessage = message;
      showSuccessMessage = true;
    });
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showSuccessMessage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A233A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Provider Hub",
          style: TextStyle(
            color: Color(0xFF1A233A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF1A233A),
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                ),
          ),
          // Keep top settings icon if you still need access to settings elsewhere
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF1A233A)),
            onPressed:
                () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder:
                      (context) =>
                          SettingsModal(onClose: () => Navigator.pop(context)),
                ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Provider Dashboard",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A233A),
                        ),
                      ),
                      const Text(
                        "Manage your services and bookings",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      const QuickStatsGrid(),
                      const SizedBox(height: 30),
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const QuickActionsRow(), // Settings removed and Reviews added inside here
                    ],
                  ),
                ),
                const SectionHeader(
                  title: "Earnings Overview",
                  actionText: "View Details",
                ),
                const EarningsOverviewCard(),
                const SectionHeader(
                  title: "Recent Bookings",
                  actionText: "View All",
                ),

                // Status Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children:
                        [
                          'all',
                          'pending',
                          'confirmed',
                          'completed',
                          'cancelled',
                        ].map((status) {
                          bool isSelected = _filterStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                status[0].toUpperCase() + status.substring(1),
                              ),
                              selected: isSelected,
                              onSelected:
                                  (val) =>
                                      setState(() => _filterStatus = status),
                              selectedColor: const Color(0xFFFF6B00),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.grey.shade100,
                              shape: const StadiumBorder(side: BorderSide.none),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                  ),
                ),

                ..._filteredBookings.map(
                  (booking) => BookingCard(
                    booking: booking,
                    onAccept: () {
                      setState(() => booking.status = BookingStatus.confirmed);
                      showSuccess("✓ Booking accepted!");
                    },
                    onDecline: () {
                      setState(() => booking.status = BookingStatus.cancelled);
                    },
                    onComplete: () {
                      setState(() => booking.status = BookingStatus.completed);
                      showSuccess("✓ Service completed!");
                    },
                  ),
                ),

                const SectionHeader(
                  title: "My Services",
                  actionText: "Manage All",
                ),
                MyServiceCard(
                  title: "House Cleaning",
                  category: "Cleaning",
                  price: "85",
                  isActive: _isHouseCleaningActive,
                  onToggle:
                      (bool value) =>
                          setState(() => _isHouseCleaningActive = value),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          if (showSuccessMessage)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          successMessage,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 1. QUICK STATS GRID (4 ITEMS)
class QuickStatsGrid extends StatelessWidget {
  const QuickStatsGrid({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: const [
        StatCard(
          title: "Total Bookings",
          value: "248",
          trend: "+12%",
          icon: Icons.calendar_today,
          colors: [Color(0xFFFF6B00), Color(0xFF0D9488)],
        ),
        StatCard(
          title: "Total Earnings",
          value: "RM 12,450",
          trend: "+8%",
          icon: Icons.monetization_on,
          colors: [Color(0xFFC084FC), Color(0xFF9333EA)],
        ),
        StatCard(
          title: "Avg Rating",
          value: "4.8",
          trend: "+0.2",
          icon: Icons.star,
          colors: [Colors.orange, Colors.orangeAccent],
        ),
        StatCard(
          title: "Active Services",
          value: "12",
          trend: "+2",
          icon: Icons.favorite,
          colors: [Colors.blue, Colors.blueAccent],
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value, trend;
  final IconData icon;
  final List<Color> colors;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    trend,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF6B00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 2. QUICK ACTIONS ROW (REPLACED SETTINGS WITH REVIEWS)
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionItem(
          context,
          "Add Service",
          Icons.add,
          const Color(0xFFFF6B00),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddServiceScreen()),
          ),
        ),
        _actionItem(
          context,
          "Messages",
          Icons.chat_bubble_outline,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          ),
        ),
        _actionItem(
          context,
          "Calendar",
          Icons.calendar_today,
          Colors.purpleAccent,
          () {},
        ),
        // 🔹 REPLACED SETTINGS WITH REVIEWS HERE
        _actionItem(
          context,
          "Reviews",
          Icons.star_outline,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProviderReviewsPage(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// 3. REVISED BOOKING CARD (MATCHES IMAGE UI)
class BookingCard extends StatelessWidget {
  final BookingData booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onComplete;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    bool isConfirmed = booking.status == BookingStatus.confirmed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  booking.avatar,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          booking.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (!isConfirmed)
                          Text(
                            "RM ${booking.price}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B00),
                            ),
                          ),
                        if (isConfirmed) _statusBadge(booking.status),
                      ],
                    ),
                    Text(
                      booking.service,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isConfirmed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    booking.location,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

          if (!isConfirmed) const Divider(height: 24),

          if (booking.status == BookingStatus.completed ||
              booking.status == BookingStatus.cancelled)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Amount",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  "RM ${booking.price}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B00),
                    fontSize: 18,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),

          if (booking.status == BookingStatus.pending)
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    "Accept",
                    const Color(0xFFFF6B00),
                    Colors.white,
                    onAccept,
                    Icons.check,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionBtn(
                    "Decline",
                    Colors.red.shade400,
                    Colors.white,
                    onDecline,
                    Icons.close,
                  ),
                ),
              ],
            )
          else if (isConfirmed)
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    "Complete",
                    const Color(0xFF22C55E),
                    Colors.white,
                    onComplete,
                    Icons.done_all,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionBtn(
                    "Cancel",
                    const Color(0xFFEF4444),
                    Colors.white,
                    onDecline,
                    Icons.close,
                  ),
                ),
              ],
            )
          else
            _actionBtn(
              "View Details",
              Colors.grey.shade100,
              Colors.grey,
              () {},
              Icons.info_outline,
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    Color color =
        status == BookingStatus.confirmed
            ? Colors.blue
            : (status == BookingStatus.completed
                ? Colors.green
                : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    Color bg,
    Color text,
    VoidCallback press,
    IconData icon,
  ) {
    return InkWell(
      onTap: press,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: text, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyServiceCard extends StatelessWidget {
  final String title, category, price;
  final bool isActive;
  final Function(bool) onToggle;
  const MyServiceCard({
    super.key,
    required this.title,
    required this.category,
    required this.price,
    required this.isActive,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: isActive,
                        onChanged: onToggle,
                        activeColor: const Color(0xFFFF6B00),
                      ),
                    ),
                  ],
                ),
                Text(
                  category,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  "RM $price",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B00),
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

class SectionHeader extends StatelessWidget {
  final String title, actionText;
  const SectionHeader({
    super.key,
    required this.title,
    required this.actionText,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            actionText,
            style: const TextStyle(
              color: Color(0xFFFF6B00),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class EarningsOverviewCard extends StatelessWidget {
  const EarningsOverviewCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "This Month",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    "RM 3,240",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "+18% from last month",
                    style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A233A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.show_chart,
              color: Color(0xFFFF6B00),
              size: 50,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Updates"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text("No new updates")),
    );
  }
}
