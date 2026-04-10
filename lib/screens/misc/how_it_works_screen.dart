import 'package:flutter/material.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  bool isCustomer = true; // 👈 default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFFFFC),
              Color(0xFFF6F9FC),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Back
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),

                const SizedBox(height: 8),

                const Text(
                  'How GoServe Works',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Get services in just a few simple steps',
                  style: TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 20),

                // 🔹 ROLE TOGGLE
                _roleToggle(),

                const SizedBox(height: 28),

                // 🔹 STEPS (dynamic)
                ..._buildSteps(),

                const Spacer(),

                // 🔹 CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 ROLE TOGGLE UI
  Widget _roleToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          _roleButton(
            label: 'Customer',
            selected: isCustomer,
            onTap: () => setState(() => isCustomer = true),
          ),
          _roleButton(
            label: 'Service Provider',
            selected: !isCustomer,
            onTap: () => setState(() => isCustomer = false),
          ),
        ],
      ),
    );
  }

  Widget _roleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF6B00) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 STEPS BUILDER
  List<Widget> _buildSteps() {
    if (isCustomer) {
      return [
        _stepCard(
          '1',
          'Browse Services',
          'Explore various local services based on your needs.',
          Icons.search,
          const Color(0xFFFF6B00),
        ),
        _stepCard(
          '2',
          'Choose Provider',
          'Select trusted service providers with good ratings.',
          Icons.handshake,
          const Color(0xFF0EA5E9),
        ),
        _stepCard(
          '3',
          'Book Appointment',
          'Schedule services at your preferred date and time.',
          Icons.calendar_today,
          const Color(0xFF4F46E5),
        ),
        _stepCard(
          '4',
          'Get It Done',
          'Relax while the service provider completes the job.',
          Icons.check_circle,
          const Color(0xFF22C55E),
        ),
      ];
    } else {
      return [
        _stepCard(
          '1',
          'Create Profile',
          'Register and set up your service provider profile.',
          Icons.person_add,
          const Color(0xFF4F46E5),
        ),
        _stepCard(
          '2',
          'List Services',
          'Add services, pricing, and availability.',
          Icons.list_alt,
          const Color(0xFF0EA5E9),
        ),
        _stepCard(
          '3',
          'Accept Bookings',
          'Receive and manage customer bookings.',
          Icons.event_available,
          const Color(0xFFFF6B00),
        ),
        _stepCard(
          '4',
          'Get Paid',
          'Complete jobs and receive secure payments.',
          Icons.payments,
          const Color(0xFF22C55E),
        ),
      ];
    }
  }

  // 🔹 STEP CARD (unchanged layout)
  Widget _stepCard(
    String number,
    String title,
    String description,
    IconData icon,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: accent,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
          Icon(icon, color: accent),
        ],
      ),
    );
  }
}
