import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gooservee/screens/chat/single_chat_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bookingTabs(),
            const SizedBox(height: 20),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _bookingTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _tabButton('Upcoming', 0),
          _tabButton('Completed', 1),
          _tabButton('Cancelled', 2),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final active = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF000000) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to see bookings"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF000000)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No bookings found", style: TextStyle(color: Colors.black54)),
          );
        }

        final allBookings = snapshot.data!.docs;

        final upcoming = allBookings.where((d) => d['status'] == 'Pending' || d['status'] == 'Confirmed').toList();
        final completed = allBookings.where((d) => d['status'] == 'Completed' || d['status'] == 'In progress').toList();
        final cancelled = allBookings.where((d) => d['status'] == 'Cancelled').toList();

        List<QueryDocumentSnapshot> displayList;
        if (selectedTab == 0) {
          displayList = upcoming;
        } else if (selectedTab == 1) {
          displayList = completed;
        } else {
          displayList = cancelled;
        }

        // Optional: sort by createdAt descending (newest first)
        displayList.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (displayList.isEmpty) {
          return const Center(
            child: Text("No bookings in this category", style: TextStyle(color: Colors.black54)),
          );
        }

        return ListView.builder(
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final data = displayList[index].data() as Map<String, dynamic>;
            final id = displayList[index].id;
            return _buildDynamicCard(data, id);
          },
        );
      },
    );
  }

  Widget _buildDynamicCard(Map<String, dynamic> data, String id) {
    String title = data['serviceName'] ?? 'Service';
    String provider = data['providerName'] ?? 'Provider';
    String price = data['totalPrice']?.toString() ?? 'RM0';
    if (!price.contains('RM')) price = 'RM$price';
    String date = data['date'] ?? 'N/A';
    String time = data['time'] ?? 'N/A';
    String location = data['address'] ?? 'N/A';
    String status = data['status'] ?? 'Pending';
    String bookingId = id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase(); 

    Color statusBg, statusColor;
    Widget actions;

    if (status == 'Pending') {
      statusBg = const Color(0xFFFFF7D6);
      statusColor = const Color(0xFFD97706);
      actions = Column(
        children: [
          ModernPrimaryButton(
            icon: Icons.chat_bubble_outline,
            text: 'Chat with Provider',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SingleChatScreen())),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: ModernSecondaryButton(text: 'Reschedule', icon: Icons.schedule)),
              const SizedBox(width: 12),
              Expanded(
                child: ModernDangerButton(
                  text: 'Cancel', 
                  icon: Icons.close, 
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('bookings').doc(id).update({'status': 'Cancelled'});
                  }
                ),
              ),
            ],
          ),
        ],
      );
    } else if (status == 'Confirmed') {
      statusBg = const Color(0xFFE0F2FE);
      statusColor = const Color(0xFF0284C7);
      actions = ModernPrimaryButton(
        icon: Icons.chat_bubble_outline,
        text: 'Chat with Provider',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SingleChatScreen())),
      );
    } else if (status == 'In progress') {
      statusBg = const Color(0xFFEDE9FE);
      statusColor = const Color(0xFF7C3AED);
      actions = const ModernSecondaryButton(text: 'Track Provider', icon: Icons.map);
    } else if (status == 'Completed') {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF047857);
      actions = ModernPrimaryButton(
        icon: Icons.star_border,
        text: 'Leave Review',
        onPressed: () => showReviewBottomSheet(context, title, provider, date, time),
      );
    } else { // Cancelled
      statusBg = const Color(0xFFFFE4E6);
      statusColor = Colors.redAccent;
      actions = ModernPrimaryButton(icon: Icons.refresh, text: 'Book Again', onPressed: () {});
    }

    return BaseCard(
      title: title,
      provider: provider,
      price: price,
      bookingId: bookingId,
      status: status,
      statusBg: statusBg,
      statusColor: statusColor,
      date: date,
      time: time,
      location: location,
      actions: actions,
    );
  }
}

// ================= REUSABLE BASE UI =================

class BaseCard extends StatelessWidget {
  final String title, provider, price, bookingId, status, date, time, location;
  final Color statusBg, statusColor;
  final Widget actions;

  const BaseCard({
    super.key, required this.title, required this.provider, required this.price,
    required this.bookingId, required this.status, required this.statusBg,
    required this.statusColor, required this.date, required this.time,
    required this.location, required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 14),
          _statusPill(),
          const Divider(height: 30),
          _infoRow(Icons.calendar_today, 'Service Date', date),
          _infoRow(Icons.access_time, 'Time', time),
          _infoRow(Icons.location_on, 'Location', location),
          const SizedBox(height: 22),
          actions,
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const CircleAvatar(radius: 28, backgroundColor: Color(0xFFEFFAF8), child: Icon(Icons.person, color: Color(0xFFFF6B00))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('by $provider', style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
            Text('ID: $bookingId', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ],
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF000000)),
          const SizedBox(width: 12),
          Text('$title: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ================= BUTTON STYLES =================

class ModernPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  const ModernPrimaryButton({super.key, required this.icon, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }
}

class ModernSecondaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  const ModernSecondaryButton({super.key, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18, color: Colors.black87),
        label: Text(text, style: const TextStyle(color: Colors.black87)),
        style: TextButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      ),
    );
  }
}

class ModernDangerButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  const ModernDangerButton({super.key, required this.text, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(icon, size: 18, color: Colors.redAccent),
        label: Text(text, style: const TextStyle(color: Colors.redAccent)),
        style: TextButton.styleFrom(backgroundColor: const Color(0xFFFFEEEE), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      ),
    );
  }
}

// ================= LEAVE REVIEW BOTTOM SHEET =================

void showReviewBottomSheet(BuildContext context, String title, String provider, String date, String time) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      int rating = 0;
      int charCount = 0;
      final TextEditingController reviewController = TextEditingController();

      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Leave a Review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Text('Share your experience with this service provider', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(width: 60, height: 60, color: const Color(0xFFE2E8F0), child: const Icon(Icons.person, color: Color(0xFFFF6B00), size: 30)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('by $provider', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFFFF6B00)),
                                  const SizedBox(width: 4),
                                  Text(date, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.access_time, size: 14, color: Color(0xFFFF6B00)),
                                  const SizedBox(width: 4),
                                  Text(time, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Row(
                    children: [
                      Icon(Icons.star_outline, size: 18, color: Color(0xFFFF6B00)),
                      SizedBox(width: 8),
                      Text('Rate Your Experience', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(5, (index) {
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(index < rating ? Icons.star : Icons.star_border, size: 40, color: index < rating ? Colors.amber : Colors.grey.shade300),
                        onPressed: () => setState(() => rating = index + 1),
                      );
                    }).expand((i) => [i, const SizedBox(width: 10)]).toList()..removeLast(),
                  ),
                  const SizedBox(height: 24),

                  const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFFFF6B00)),
                      SizedBox(width: 8),
                      Text('Write Your Review', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (val) => setState(() => charCount = val.length),
                    decoration: InputDecoration(
                      hintText: 'Tell us about your experience...',
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
                      counterText: "$charCount/500 characters",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
