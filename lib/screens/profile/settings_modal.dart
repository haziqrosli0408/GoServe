import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsModal extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsModal({super.key, required this.onClose});

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Firebase References
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Profile Data
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Business Data
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  String _cancellationPolicy = "24 hours";
  bool _autoAcceptBookings = true;

  // Working Hours Data
  final Map<String, Map<String, String>> _workingHours = {
    'Monday': {'start': '09:00', 'end': '18:00'},
    'Tuesday': {'start': '09:00', 'end': '18:00'},
    'Wednesday': {'start': '09:00', 'end': '18:00'},
    'Thursday': {'start': '09:00', 'end': '18:00'},
    'Friday': {'start': '09:00', 'end': '18:00'},
    'Saturday': {'start': '09:00', 'end': '18:00'},
    'Sunday': {'start': '09:00', 'end': '18:00'},
  };

  // Notification States
  bool _newBookings = true;
  bool _bookingReminders = true;
  bool _messages = true;
  bool _reviews = true;
  bool _promotions = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;

  // Privacy States
  bool _showPhoneNumber = true;
  bool _showEmail = false;
  bool _showLocation = true;
  bool _allowReviews = true;
  String _profileVisibility = "public";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFirebaseData();
  }

  Future<void> _loadFirebaseData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "";
          _emailController.text = data['email'] ?? user.email ?? "";
          _phoneController.text = data['phone'] ?? "";
          _bioController.text = data['bio'] ?? "";
          _businessNameController.text = data['businessName'] ?? "";
          _addressController.text = data['address'] ?? "";
          _taxIdController.text = data['taxId'] ?? "";
          _cancellationPolicy = data['cancellationPolicy'] ?? "24 hours";
          _autoAcceptBookings = data['autoAcceptBookings'] ?? true;

          if (data['workingHours'] != null) {
            Map<String, dynamic> hours = data['workingHours'];
            hours.forEach((key, value) {
              _workingHours[key] = {
                'start': value['start'],
                'end': value['end'],
              };
            });
          }

          _newBookings = data['notif_newBookings'] ?? true;
          _bookingReminders = data['notif_reminders'] ?? true;
          _messages = data['notif_messages'] ?? true;
          _reviews = data['notif_reviews'] ?? true;
          _promotions = data['notif_promotions'] ?? false;
          _emailNotifications = data['notif_email'] ?? true;
          _pushNotifications = data['notif_push'] ?? true;
          _showPhoneNumber = data['priv_showPhone'] ?? true;
          _showEmail = data['priv_showEmail'] ?? false;
          _showLocation = data['priv_showLoc'] ?? true;
          _allowReviews = data['priv_allowReviews'] ?? true;
          _profileVisibility = data['profileVisibility'] ?? "public";
        });
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(
    BuildContext context,
    String day,
    String type,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_workingHours[day]![type]!.split(':')[0]),
        minute: int.parse(_workingHours[day]![type]!.split(':')[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        _workingHours[day]![type] =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _handleSave() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'bio': _bioController.text,
          'businessName': _businessNameController.text,
          'address': _addressController.text,
          'taxId': _taxIdController.text,
          'cancellationPolicy': _cancellationPolicy,
          'autoAcceptBookings': _autoAcceptBookings,
          'workingHours': _workingHours,
          'notif_newBookings': _newBookings,
          'notif_reminders': _bookingReminders,
          'notif_messages': _messages,
          'notif_reviews': _reviews,
          'notif_promotions': _promotions,
          'notif_email': _emailNotifications,
          'notif_push': _pushNotifications,
          'priv_showPhone': _showPhoneNumber,
          'priv_showEmail': _showEmail,
          'priv_showLoc': _showLocation,
          'priv_allowReviews': _allowReviews,
          'profileVisibility': _profileVisibility,
        }, SetOptions(merge: true));

        widget.onClose();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        // Redirects to root ('/') which is the IntroScreen and clears history
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(
                    Icons.close,
                    size: 28,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFFFF6B00),
            labelColor: const Color(0xFF0D9488),
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: "Profile"),
              Tab(text: "Business"),
              Tab(text: "Updates"),
              Tab(text: "Privacy"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildBusinessTab(),
                _buildNotificationsTab(),
                _buildPrivacyTab(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF374151),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Save Changes"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB BUILDERS ---
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLabel("Full Name"),
        _buildTextField(_nameController, "Name"),
        _buildLabel("Email"),
        _buildTextField(
          _emailController,
          "Email",
          keyboardType: TextInputType.emailAddress,
        ),
        _buildLabel("Phone Number"),
        _buildTextField(
          _phoneController,
          "Phone",
          keyboardType: TextInputType.phone,
        ),
        _buildLabel("Bio"),
        _buildTextField(_bioController, "Bio", maxLines: 3),
      ],
    );
  }

  Widget _buildBusinessTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLabel("Business Name"),
        _buildTextField(_businessNameController, "Business Name"),
        _buildLabel("Business Address"),
        _buildTextField(_addressController, "Address"),
        _buildLabel("Tax ID"),
        _buildTextField(_taxIdController, "Tax ID"),
        _buildLabel("Cancellation Policy"),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _cancellationPolicy,
              isExpanded: true,
              items:
                  ["flexible", "24 hours", "48 hours", "1 week", "strict"]
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _cancellationPolicy = val!),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildToggleTile(
          "Auto-Accept Bookings",
          "Automatically accept requests",
          _autoAcceptBookings,
          (v) => setState(() => _autoAcceptBookings = v),
        ),
        const SizedBox(height: 10),
        ..._workingHours.keys.map(
          (day) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(day, style: const TextStyle(fontSize: 14)),
                ),
                _buildTimeInput(
                  _workingHours[day]!['start']!,
                  () => _selectTime(context, day, 'start'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("-"),
                ),
                _buildTimeInput(
                  _workingHours[day]!['end']!,
                  () => _selectTime(context, day, 'end'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildToggleTile(
          "New Bookings",
          "Notify on receive",
          _newBookings,
          (v) => setState(() => _newBookings = v),
        ),
        _buildToggleTile(
          "Messages",
          "New customer messages",
          _messages,
          (v) => setState(() => _messages = v),
        ),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildToggleTile(
          "Show Phone Number",
          "Visible on profile",
          _showPhoneNumber,
          (v) => setState(() => _showPhoneNumber = v),
        ),
        _buildLabel("Profile Visibility"),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _profileVisibility,
              isExpanded: true,
              items:
                  ["public", "registered", "private"]
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _profileVisibility = val!),
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildActionRow(
          "Data & Privacy",
          "Manage settings",
          Icons.arrow_forward_ios,
        ),
        GestureDetector(
          onTap: _handleLogout,
          child: _buildActionRow(
            "Log Out",
            "Sign out of your session",
            Icons.logout,
          ),
        ),
        _buildActionRow(
          "Delete Account",
          "Permanently delete account",
          Icons.arrow_forward_ios,
          isDestructive: true,
        ),
      ],
    );
  }

  // --- HELPERS ---
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 15),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    ),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF6B00),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInput(String time, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(time, style: const TextStyle(fontSize: 12)),
    ),
  );

  Widget _buildActionRow(
    String title,
    String subtitle,
    IconData icon, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDestructive ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDestructive ? Colors.red[300] : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          Icon(
            icon,
            size: 14,
            color: isDestructive ? Colors.red : const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }
}
