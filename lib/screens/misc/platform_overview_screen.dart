import 'package:flutter/material.dart';

class PlatformOverviewScreen extends StatelessWidget {
  const PlatformOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Overview'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Title
            const Text(
              'Platform Overview',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Three powerful account types for everyone',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // 🔹 Customer Card
            _overviewCard(
              icon: Icons.person,
              title: 'Customer Account',
              description:
                  'Browse services, book appointments, and track your orders easily.',
              color: Colors.teal,
            ),

            const SizedBox(height: 16),

            // 🔹 Provider Card
            _overviewCard(
              icon: Icons.storefront,
              title: 'Provider Account',
              description:
                  'Manage listings, handle bookings, and grow your service business.',
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // 🔹 Admin Card
            _overviewCard(
              icon: Icons.admin_panel_settings,
              title: 'Admin Panel',
              description:
                  'Complete system control including user and service management.',
              color: Colors.deepPurple,
            ),

            const Spacer(),

            // 🔹 Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text(
                  'Register Now',
                  style: TextStyle(fontSize: 16),
                
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Reusable Card Widget
  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
