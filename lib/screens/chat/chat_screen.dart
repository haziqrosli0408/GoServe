import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'single_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isMenuOpen = false;
  bool _isSelectionMode = false;
  bool _isSearching = false;
  final Set<String> _selectedChats = {};
  final TextEditingController _searchController = TextEditingController();
  
  // Dynamic list of chats
  final List<Map<String, dynamic>> _allChats = [
    {
      'name': 'Sarah Johnson',
      'service': 'Professional Cleaning',
      'message': 'Work perfectly!',
      'time': '10:35 AM',
      'isRead': true,
    },
    {
      'name': 'Mike Hammer',
      'service': 'Plumbing Expert',
      'message': 'I can come over later today.',
      'time': 'Yesterday',
      'isRead': false,
    },
    {
      'name': 'Elite Gardening',
      'service': 'Landscaping',
      'message': 'Your quote is ready for review.',
      'time': 'Wed',
      'isRead': true,
    },
  ];

  List<Map<String, dynamic>> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _filteredChats = _allChats;
  }

  void _onSearch(String query) {
    setState(() {
      _filteredChats = _allChats.where((chat) {
        final name = chat['name'].toString().toLowerCase();
        final service = chat['service'].toString().toLowerCase();
        final msg = chat['message'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || 
               service.contains(query.toLowerCase()) ||
               msg.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Inline Expanded Menu
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isMenuOpen ? 50 : 0,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ArchivedChatScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Archived',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6B00),
                        ),
                      ),
                    ),
                  ),
                  Divider(color: Colors.grey.shade50, height: 1),
                ],
              ),
            ),
          ),
          Expanded(
            child: _filteredChats.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = _filteredChats[index];
                    return _buildChatItem(chat);
                  },
                ),
          ),
          if (_isSelectionMode && _selectedChats.isNotEmpty)
            _buildStickyBottomActions(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedChats.clear();
            });
          },
        ),
        title: Text(
          '${_selectedChats.length} Selected',
          style: GoogleFonts.outfit(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      );
    }

    if (_isSearching) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _filteredChats = _allChats;
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
            border: InputBorder.none,
          ),
          style: GoogleFonts.outfit(fontSize: 18),
        ),
      );
    }

    return AppBar(
      automaticallyImplyLeading: false, 
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: GestureDetector(
        onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
        child: Container(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Messages',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isMenuOpen ? 0.5 : 0,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 24),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 22),
          onPressed: () {
            setState(() {
              _isSelectionMode = true;
              _isMenuOpen = false;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black, size: 22),
          onPressed: () {
            setState(() {
              _isSearching = true;
              _isMenuOpen = false;
            });
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStickyBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), 
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Archived ${_selectedChats.length} chats')),
                );
                setState(() {
                  _isSelectionMode = false;
                  _selectedChats.clear();
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFFF3F4F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), 
                ),
              ),
              child: Text(
                'Archive',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF6B7280), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${_selectedChats.length} chats')),
                );
                setState(() {
                  _isSelectionMode = false;
                  _selectedChats.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final String name = chat['name'];
    final String service = chat['service'];
    final String message = chat['message'];
    final String time = chat['time'];
    final bool isRead = chat['isRead'];
    final bool isSelected = _selectedChats.contains(name);

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedChats.remove(name);
                } else {
                  _selectedChats.add(name);
                }
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SingleChatScreen(provider: {'name': name})),
              );
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedChats.add(name);
              });
            }
          },
          child: Container(
            color: isSelected ? const Color(0xFFFFF7ED).withValues(alpha: 0.5) : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                // Animated Selection Circle from Left
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSelectionMode ? 32 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isSelectionMode ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFFFF6B00) : Colors.grey.shade300,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                
                // Chat Content
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$name'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Provider Name & Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: const Color(0xFFFF6B00),
                                  ),
                                ),
                                Text(
                                  time,
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),

                            // Service Name
                            Text(
                              service,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1F2937),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Latest Message
                            Text(
                              message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: isRead ? Colors.grey.shade500 : const Color(0xFF1F2937),
                                fontSize: 14,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(color: Colors.grey.shade100, height: 1, thickness: 1),
      ],
    );
  }
}

class ArchivedChatScreen extends StatelessWidget {
  const ArchivedChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Text(
          'Archived',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            color: Colors.black,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          _buildArchivedChatItem(
            context,
            name: 'Quick Fix Hardware',
            service: 'Tools & Supplies',
            message: 'Your order is ready for pickup.',
            time: '2 Oct',
          ),
          _buildArchivedChatItem(
            context,
            name: 'Clean Slate Ltd',
            service: 'Deep Cleaning',
            message: 'Thank you for choosing our service.',
            time: '28 Sep',
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedChatItem(
    BuildContext context, {
    required String name,
    required String service,
    required String message,
    required String time,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$name'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFFFF6B00),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.outfit(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1F2937),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey.shade100, height: 1, thickness: 1),
      ],
    );
  }
}

