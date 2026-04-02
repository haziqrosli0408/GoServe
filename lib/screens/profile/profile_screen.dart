import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (!mounted) return;

    setState(() {
      userData = doc.data() ?? {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔹 HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'My Profile',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1F212C),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 🔹 PROFILE CARD
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${userData!['name']}'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userData!['name'] ?? 'User Name',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F212C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userData!['email'] ?? 'email@example.com',
                        style: GoogleFonts.outfit(color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ProfileStat(
                              icon: Icons.calendar_today_outlined,
                              value: '12',
                              label: 'Bookings'),
                          _ProfileStat(
                              icon: Icons.star_outline_rounded,
                              value: '4.8',
                              label: 'Rating'),
                          _ProfileStat(
                              icon: Icons.favorite_border_rounded,
                              value: '24',
                              label: 'Saved'),
                        ],
                      ),
                    ],
                  ),
                ),

                // 🔹 SETTINGS LIST
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _settingTile(
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        title: 'Edit Profile',
                        subtitle: 'Update your personal information',
                        onTap: () => _showEditProfile(context),
                      ),
                      _settingTile(
                        icon: Icons.location_on_outlined,
                        color: Colors.green,
                        title: 'Saved Addresses',
                        subtitle: 'Manage delivery addresses',
                      ),
                      _settingTile(
                        icon: Icons.credit_card,
                        color: Colors.purple,
                        title: 'Payment Methods',
                        subtitle: 'Manage payment options',
                      ),
                      _settingTile(
                        icon: Icons.notifications_outlined,
                        color: Colors.orange,
                        title: 'Updates',
                        subtitle: 'App alerts and updates',
                      ),
                      _settingTile(
                        icon: Icons.help_outline,
                        color: Colors.amber,
                        title: 'Help & Support',
                        subtitle: 'Get help & support',
                      ),

                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () => _showLogoutDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // 📌 EDIT PROFILE — EXACT UI AS YOUR PIC
  void _showEditProfile(BuildContext context) {
    final nameController =
        TextEditingController(text: userData!['name'] ?? '');
    final emailController =
        TextEditingController(text: userData!['email'] ?? '');
    final phoneController =
        TextEditingController(text: userData!['phone'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Edit Profile",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFFE5E7EB),
                      child:
                          Icon(Icons.person, size: 45, color: Colors.grey),
                    ),
                  ),

                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text("Change Photo",
                          style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 18),

                  _editField("Full Name", nameController),
                  _editField("Email Address", emailController),
                  _editField("Phone Number", phoneController),

                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection("users")
                                .doc(user!.uid)
                                .update({
                              "name": nameController.text.trim(),
                              "email": emailController.text.trim(),
                              "phone": phoneController.text.trim(),
                            });

                            await fetchUserData();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Save Changes"),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter $label",
              filled: true,
              fillColor: const Color(0xFFF7F9FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // LOGOUT
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, "/login");
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}

// Small reusable components
class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE6FFFA),
          child: Icon(icon, size: 18, color: Color(0xFFFF6B00)),
        ),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

Widget _settingTile({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  VoidCallback? onTap,
}) {
  return ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(vertical: 5),
    leading: CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    ),
    title: Text(title,
        style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
  );
}
