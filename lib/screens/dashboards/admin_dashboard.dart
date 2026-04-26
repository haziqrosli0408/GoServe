import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // State Management
  String activeTab = 'overview';
  String timeRange = '30days';
  String searchQuery = '';
  String statusFilter = 'all';

  // 🔹 State variables for service toggles
  bool isHomeCleaningActive = true;
  bool isElectricalRepairActive = false;

  final Color primaryTeal = const Color(0xFFFF6B00);
  final Color primaryOrange = Colors.orange;

  // Logout logic
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'GoServe Admin',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.black54),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(radius: 16, backgroundColor: Colors.orange),
          ),
        ],
      ),
      // 🔹 Added Floating Action Button for quick chat
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/admin-chat-list'),
        backgroundColor: primaryTeal,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabNavigation(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTabContent(),
                  const SizedBox(height: 30),
                  _buildTalkWithSupport(), // 🔹 Added Support Banner at bottom
                  const SizedBox(height: 80), // Extra space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW SUPPORT COMPONENT ---
  Widget _buildTalkWithSupport() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headset_mic, color: Colors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reply the FAQ?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigation to internal support or dev chat
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }

  // --- HEADER & NAVIGATION ---

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const Text(
            'Manage your service marketplace',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['Today', '7 Days', '30 Days', '90 Days', 'Year'].map((
                    range,
                  ) {
                    bool isSelected =
                        timeRange == range.toLowerCase().replaceAll(' ', '');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(range),
                        selected: isSelected,
                        onSelected:
                            (s) => setState(
                              () =>
                                  timeRange = range.toLowerCase().replaceAll(
                                    ' ',
                                    '',
                                  ),
                            ),
                        selectedColor: primaryTeal,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    final List<Map<String, dynamic>> tabs = [
      {'id': 'overview', 'icon': Icons.dashboard},
      {'id': 'bookings', 'icon': Icons.calendar_today},
      {'id': 'services', 'icon': Icons.handyman},
      {'id': 'providers', 'icon': Icons.badge},
      {'id': 'verification', 'icon': Icons.verified_user_rounded},
      {'id': 'users', 'icon': Icons.people},
      {'id': 'reviews', 'icon': Icons.star},
      {'id': 'reports', 'icon': Icons.bar_chart},
    ];

    return Container(
      height: 55,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          bool isSelected = activeTab == tabs[index]['id'];
          return GestureDetector(
            onTap: () => setState(() => activeTab = tabs[index]['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? primaryTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    tabs[index]['icon'],
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tabs[index]['id'].toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (activeTab) {
      case 'overview':
        return _buildOverview();
      case 'bookings':
        return _buildBookings();
      case 'services':
        return _buildServices();
      case 'providers':
        return _buildProviders();
      case 'verification':
        return _buildVerificationTab();
      case 'users':
        return _buildUsers();
      case 'reviews':
        return _buildReviews();
      case 'reports':
        return _buildReports();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  // --- 1. OVERVIEW TAB ---
  Widget _buildOverview() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            _statCard('Bookings', '1,247', Icons.calendar_month, Colors.teal),
            _statCard('Revenue', 'RM 156K', Icons.payments, Colors.green),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('providers').snapshots(),
              builder: (context, snapshot) {
                return _statCard('Providers', snapshot.hasData ? snapshot.data!.docs.length.toString() : '...', Icons.store, Colors.blue);
              }
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                return _statCard('Users', snapshot.hasData ? snapshot.data!.docs.length.toString() : '...', Icons.group, Colors.purple);
              }
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader('Recent Bookings'),
        _bookingCard(
          'Home Deep Cleaning',
          'Hajiq Rosli.',
          'Confirmed',
          Colors.blue,
          150,
        ),
        _bookingCard(
          'Electrical Wiring',
          'Sofi.',
          'Pending',
          Colors.orange,
          200,
        ),
      ],
    );
  }

  // --- 2. BOOKINGS TAB ---
  Widget _buildBookings() {
    return Column(
      children: [
        _buildSearchField('Search bookings...'),
        const SizedBox(height: 16),
        _bookingCard(
          'Home Deep Cleaning',
          'Hajiq Rosli.',
          'Confirmed',
          Colors.blue,
          150,
          showDetails: true,
        ),
        _bookingCard(
          'Electrical Wiring',
          'Sofi.',
          'Pending',
          Colors.orange,
          200,
          showDetails: true,
        ),
      ],
    );
  }

  // --- 3. SERVICES TAB ---
  Widget _buildServices() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/add-service');
          },
          icon: const Icon(Icons.add),
          label: const Text("Add New Service"),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 45),
          ),
        ),
        const SizedBox(height: 16),
        _serviceCard(
          'Home Deep Cleaning',
          'Hajiq Rosli.',
          150,
          isHomeCleaningActive,
          (val) {
            setState(() {
              isHomeCleaningActive = val;
            });
          },
        ),
        _serviceCard(
          'Electrical Repair',
          'Sofi.',
          80,
          isElectricalRepairActive,
          (val) {
            setState(() {
              isElectricalRepairActive = val;
            });
          },
        ),
      ],
    );
  }

  // --- 4. PROVIDERS TAB ---
  Widget _buildProviders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('providers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No providers found'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Provider';
            final String service =
                (data['services'] is List &&
                        (data['services'] as List).isNotEmpty)
                    ? (data['services'] as List).first.toString()
                    : 'No services listed';
            final String status = data['status'] ?? 'Active';
            final String profileUrl = data['profileUrl'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue,
                          backgroundImage:
                              profileUrl.isNotEmpty
                                  ? NetworkImage(profileUrl)
                                  : null,
                          child:
                              profileUrl.isEmpty
                                  ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                service,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data['verificationStatus'] == 'verified')
                          const Icon(
                            Icons.verified,
                            color: Colors.teal,
                            size: 18,
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _providerStat(
                          'Role',
                          data['role']?.toString().toUpperCase() ?? 'PROVIDER',
                        ),
                        _providerStat('ID', data['customId'] ?? 'PENDING'),
                        _providerStat('Status', status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showProviderProfile(),
                            child: const Text('View Profile'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showSuspendDialog(),
                          icon: const Icon(Icons.block, color: Colors.orange),
                        ),
                        IconButton(
                          onPressed: () => _showDeleteDialog(),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
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

  // --- 4.5 VERIFICATION TAB ---
  Widget _buildVerificationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('providers')
              .where('verificationStatus', isEqualTo: 'pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending verifications',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String id = docs[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage:
                      (data['profileUrl'] != null &&
                              data['profileUrl'].toString().isNotEmpty)
                          ? NetworkImage(data['profileUrl'])
                          : null,
                  child:
                      data['profileUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                ),
                title: Text(
                  data['name'] ?? 'Provider',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Requested identity verification'),
                trailing: ElevatedButton(
                  onPressed: () => _showVerificationReviewModal(id, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Review',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVerificationReviewModal(
    String providerId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Review Identity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selfie vs ID Card',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'IC Front',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      data['icFrontUrl'] ?? data['icUrl'] ?? '',
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'IC Back',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      data['icBackUrl'] ?? '',
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Selfie Comparison',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            data['selfieUrl'] ?? '',
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Provider Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _detailRow('Full Name', data['name'] ?? 'N/A'),
                        _detailRow('Email', data['email'] ?? 'N/A'),
                        _detailRow('Address', data['address'] ?? 'N/A'),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('providers')
                              .doc(providerId)
                              .update({'verificationStatus': 'rejected'});
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('providers')
                              .doc(providerId)
                              .update({'verificationStatus': 'verified'});
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Approve Provider',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // --- 5. USERS TAB ---
  Widget _buildUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No customers found'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String name = data['name'] ?? 'Anonymous';
            final String email = data['email'] ?? 'No email';
            final String profileUrl = data['profileUrl'] ?? '';
            final String customId = data['customId'] ?? 'PENDING';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  backgroundImage:
                      profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child:
                      profileUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$email • Customer'),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $customId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(child: Text('Suspend User')),
                        const PopupMenuItem(child: Text('Delete User')),
                      ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 6. REVIEWS TAB ---
  Widget _buildReviews() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Miju', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '2025-05-09',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const Text(
                  '5.0 ⭐ • Home Deep Cleaning',
                  style: TextStyle(color: Colors.teal, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text('Good Service.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Approve',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
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
  }

  // --- 7. REPORTS TAB ---
  Widget _buildReports() {
    return Column(
      children: [
        _reportCard('Revenue Report', Icons.money, Colors.green),
        _reportCard('Booking Report', Icons.book, Colors.blue),
        _reportCard('Provider Performance', Icons.star, Colors.purple),
      ],
    );
  }

  // --- MODALS & DIALOGS ---

  void _showBookingDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _modalContainer(
            title: 'Booking Details',
            child: Column(
              children: [
                _detailRow('Booking ID', 'BK001'),
                _detailRow('Service', 'Home Deep Cleaning'),
                _detailRow('Customer', 'John Smith (+60 11-234 5678)'),
                _detailRow('Amount', 'RM 155.00 (Incl. Fee)'),
                const Divider(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Timeline',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                _timeline('Booking Created', '10:30 AM', true),
                _timeline('Payment Confirmed', '10:32 AM', true),
                _timeline('Provider Confirmed', '11:15 AM', true),
                _timeline('Service Completed', 'Pending', false),
              ],
            ),
          ),
    );
  }

  void _showEditService() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Service'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(
                  decoration: InputDecoration(labelText: 'Service Name'),
                ),
                const TextField(
                  decoration: InputDecoration(labelText: 'Price (RM)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showProviderProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _modalContainer(
            title: 'Provider Profile',
            child: Column(
              children: [
                const CircleAvatar(radius: 40, backgroundColor: Colors.teal),
                const SizedBox(height: 12),
                const Text(
                  'Hajiq Rosli',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Hajiq@gmail.com',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                _detailRow('Completion Rate', '98%'),
                _detailRow('Response Time', 'Within 2 hours'),
              ],
            ),
          ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showSuspendDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.warning, color: Colors.orange, size: 40),
            title: const Text('Suspend Provider?'),
            content: const Text(
              'This will prevent the provider from accepting new bookings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Suspend'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 40),
            title: const Text('Delete Provider?'),
            content: const Text('Type "DELETE" to confirm permanent removal.'),
            actions: [
              TextField(onChanged: (v) {}),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Confirm Delete'),
              ),
            ],
          ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _bookingCard(
    String s,
    String p,
    String status,
    Color c,
    int price, {
    bool showDetails = false,
  }) {
    return GestureDetector(
      onTap: showDetails ? () => _showBookingDetails() : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF3F4F6),
              child: Icon(
                Icons.cleaning_services,
                color: Colors.teal,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    'Provider: $p',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM $price',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: c,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(
    String name,
    String provider,
    int price,
    bool active,
    ValueChanged<bool> onToggle,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'by $provider',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    'RM $price',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: _showEditService,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                Switch(
                  value: active,
                  activeColor: Colors.teal,
                  onChanged: onToggle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _providerStat(String l, String v) => Column(
    children: [
      Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );

  Widget _reportCard(String t, IconData i, Color c) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(i, color: c),
      title: Text(t),
      trailing: const Icon(Icons.download),
    ),
  );

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Text(
          'View All',
          style: TextStyle(color: Colors.teal, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _modalContainer({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _timeline(String t, String time, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.circle_outlined,
          color: done ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 12),
        Text(t),
        const Spacer(),
        Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    ),
  );
}
