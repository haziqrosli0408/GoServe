import 'package:flutter/material.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  int selectedTab = 0; // 0 = Top Providers, 1 = Nearby
  String selectedNearbyCategory = 'All Categories';

  // 🌈 Colorful Categories (LIKE YOUR IMAGE)
  final categories = const [
    {
      'name': 'Cleaning',
      'icon': Icons.cleaning_services,
      'bg': Color(0xFFE0F2FE),
      'iconColor': Color(0xFF0284C7),
    },
    {
      'name': 'Plumbing',
      'icon': Icons.plumbing,
      'bg': Color(0xFFE0F7FA),
      'iconColor': Color(0xFFFF6B00),
    },
    {
      'name': 'Electrical',
      'icon': Icons.electrical_services,
      'bg': Color(0xFFFEF3C7),
      'iconColor': Color(0xFFF59E0B),
    },
    {
      'name': 'Gardening',
      'icon': Icons.grass,
      'bg': Color(0xFFECFDF5),
      'iconColor': Color(0xFF16A34A),
    },
    {
      'name': 'Painting',
      'icon': Icons.format_paint,
      'bg': Color(0xFFF3E8FF),
      'iconColor': Color(0xFF7C3AED),
    },
    {
      'name': 'Moving',
      'icon': Icons.local_shipping,
      'bg': Color(0xFFFFEDD5),
      'iconColor': Color(0xFFEA580C),
    },
  ];

  final providers = List.generate(6, (index) {
    return {
      'name': 'Sarah Johnson',
      'service': 'Professional House Cleaning',
      'price': 'RM45/hr',
      'rating': '4.9',
      'reviews': '127',
      'distance': '${(index + 1) * 2.5} km',
    };
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchBar(),
            const SizedBox(height: 16),
            _autoLocationCard(),
            const SizedBox(height: 16),
            _heroCard(),
            const SizedBox(height: 24),

            // 🔥 POPULAR CATEGORIES
            const Text(
              'Popular Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _popularCategoryScroller(),

            const SizedBox(height: 24),

            // 🔀 TOGGLE (Top Providers / Nearby)
            _toggleTabs(),
            const SizedBox(height: 16),

            if (selectedTab == 1) _nearbyCategoryDropdown(),
            const SizedBox(height: 12),

            _providerGrid(providers),
          ],
        ),
      ),
    );
  }

  // ===================== UI COMPONENTS =====================

  Widget _searchBar() {
    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        hintText: 'Search for services...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _autoLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFFF6B00),
            child: Icon(Icons.location_on, color: Colors.white),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Location Detection',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Find nearby providers instantly',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFF0EA5E9)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.home_repair_service, size: 70, color: Colors.white),
      ),
    );
  }

  // 🌈 COLORFUL CATEGORY SCROLLER
  Widget _popularCategoryScroller() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Container(
            width: 95,
            decoration: BoxDecoration(
              color: cat['bg'] as Color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  color: cat['iconColor'] as Color,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  cat['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔀 TOGGLE BUTTON
  Widget _toggleTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _tabButton('Top Providers', 0),
          _tabButton('Nearby', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF6B00) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nearbyCategoryDropdown() {
    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButton<String>(
        value: selectedNearbyCategory,
        underline: const SizedBox(),
        items: [
          'All Categories',
          ...categories.map((c) => c['name'] as String),
        ]
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => selectedNearbyCategory = v!),
      ),
    );
  }

  // 👤 PROVIDER GRID
  Widget _providerGrid(List<Map<String, String>> list) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) => _providerCard(list[i]),
    );
  }

  // 🧑 PROVIDER CARD (LIKE YOUR IMAGE)
  Widget _providerCard(Map<String, String> p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE5E7EB),
            child: Icon(Icons.person, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            p['name']!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            p['service']!,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              Text('${p['rating']} (${p['reviews']})'),
              const SizedBox(width: 8),
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              Text(p['distance']!),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p['price']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B00),
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Book'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
