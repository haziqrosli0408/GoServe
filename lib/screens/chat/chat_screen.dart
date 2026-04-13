import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'single_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final Color themeColor;
  const ChatScreen({super.key, this.themeColor = const Color(0xFFFF6B00)});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool isSelectionMode = false;
  final Set<String> selectedChatIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleBulkAction(String action) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || selectedChatIds.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var chatId in selectedChatIds) {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      if (action == 'delete') {
        batch.delete(docRef);
      }
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() {
          selectedChatIds.clear();
          isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Conversations deleted")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _isSearching 
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: GoogleFonts.outfit(fontSize: 15),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Search by name or service...',
                          hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 15),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              )
          : Text(
              isSelectionMode ? '${selectedChatIds.length} Selected' : 'Messages',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, 
                color: Colors.black,
                fontSize: 24,
              ),
            ),
        actions: [
          if (currentUser != null && !isSelectionMode)
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: _isSearching ? widget.themeColor : Colors.black87,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = "";
                  }
                });
              },
            ),
          if (currentUser != null)
            IconButton(
              icon: Icon(
                isSelectionMode ? Icons.close_rounded : Icons.checklist_rtl_rounded,
                color: isSelectionMode ? widget.themeColor : Colors.black87,
              ),
              onPressed: () {
                setState(() {
                  if (isSelectionMode) {
                    selectedChatIds.clear();
                  }
                  isSelectionMode = !isSelectionMode;
                  _isSearching = false;
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text("Please login to see messages"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error loading messages: ${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Hide deleted chats for this user
                  final deletedBy = data['deletedBy'] as List? ?? [];
                  if (deletedBy.contains(currentUser.uid)) {
                    return false;
                  }

                  final participants = data['participants'];
                  bool isParticipant = false;
                  if (participants is List) {
                    isParticipant = participants.contains(currentUser.uid);
                  } else if (participants is Map) {
                    isParticipant = participants.containsKey(currentUser.uid);
                  }

                  if (!isParticipant) return false;

                  // Search Filter
                  if (_searchQuery.isNotEmpty) {
                    final dynamic participantsRaw = data['participants'];
                    String otherId = '';
                    if (participantsRaw is List) {
                      otherId = participantsRaw.firstWhere((id) => id != currentUser.uid, orElse: () => '');
                    } else if (participantsRaw is Map) {
                      otherId = participantsRaw.keys.firstWhere((id) => id != currentUser.uid, orElse: () => '');
                    }
                    
                    final Map<String, dynamic>? otherUserData = data['users']?[otherId] as Map<String, dynamic>?;
                    
                    final String name = (otherUserData?['name'] ?? '').toString().toLowerCase();
                    final String service = (data['serviceTitle'] ?? 
                                         data['service_title'] ??
                                         otherUserData?['serviceName'] ?? 
                                         otherUserData?['service'] ?? 
                                         '').toString().toLowerCase();
                    final String lastMsg = (data['lastMessage'] ?? '').toString().toLowerCase();

                    if (!name.contains(_searchQuery) && 
                        !service.contains(_searchQuery) && 
                        !lastMsg.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();
                
                // Sort manually in memory
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTs = aData['lastTimestamp'] as Timestamp?;
                  final bTs = bData['lastTimestamp'] as Timestamp?;
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey.shade200),
                        const SizedBox(height: 16),
                        Text(
                          "No messages yet",
                          style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start a conversation with a provider to see it here.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final chatDoc = docs[index];
                        final chatData = chatDoc.data() as Map<String, dynamic>;
                        final String chatId = chatDoc.id;

                        // Get the other user's data
                        final String otherUserId = (chatData['participants'] as List)
                            .firstWhere((id) => id != currentUser.uid, orElse: () => '');
                        
                        final Map<String, dynamic>? otherUserData = chatData['users']?[otherUserId] as Map<String, dynamic>?;
                        final String otherName = otherUserData?['name'] ?? 'User';
                        final String otherPhoto = otherUserData?['photo'] ?? '';
                        
                        // Robust extraction of service name
                        String serviceName = chatData['serviceTitle'] ?? 
                                             chatData['service_title'] ??
                                             otherUserData?['serviceName'] ?? 
                                             otherUserData?['service'] ?? 
                                             '';
                        
                        if (serviceName.isEmpty) {
                          final users = chatData['users'] as Map<String, dynamic>?;
                          if (users != null) {
                            for (var user in users.values) {
                              if (user is Map && (user['serviceName'] != null || user['service'] != null)) {
                                serviceName = user['serviceName'] ?? user['service'] ?? '';
                                if (serviceName.isNotEmpty) break;
                              }
                            }
                          }
                        }

                        if (serviceName.isEmpty) {
                          serviceName = chatData['category'] ?? 'Service';
                        }
                        
                        final String lastMessage = chatData['lastMessage'] ?? 'No messages yet';
                        final Timestamp? lastTimestamp = chatData['lastTimestamp'] as Timestamp?;
                        final String timeStr = lastTimestamp != null 
                            ? (DateTime.now().difference(lastTimestamp.toDate()).inDays < 1 
                                ? DateFormat('h:mm a').format(lastTimestamp.toDate())
                                : DateFormat('MMM d').format(lastTimestamp.toDate()))
                            : '';
                        
                        final int unreadCount = (chatData['unreadCount']?[currentUser.uid] ?? 0) as int;

                        return _buildChatItem(
                          context,
                          chatId: chatId,
                          name: otherName,
                          photo: otherPhoto,
                          service: serviceName,
                          lastMessage: lastMessage,
                          time: timeStr,
                          unreadCount: unreadCount,
                          otherUserId: otherUserId,
                        );
                      },
                    ),
                    if (isSelectionMode && selectedChatIds.isNotEmpty)
                      _buildSelectionBottomBar(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSelectionBottomBar() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${selectedChatIds.length} chats selected",
              style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            GestureDetector(
              onTap: () => _handleBulkAction('delete'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Delete",
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(
    BuildContext context, {
    required String chatId,
    required String name,
    required String photo,
    required String service,
    required String lastMessage,
    required String time,
    required int unreadCount,
    required String otherUserId,
  }) {
    final bool isSelected = selectedChatIds.contains(chatId);

    return GestureDetector(
      onTap: () {
        if (isSelectionMode) {
          setState(() {
            if (isSelected) {
              selectedChatIds.remove(chatId);
            } else {
              selectedChatIds.add(chatId);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SingleChatScreen(
                chatId: chatId,
                themeColor: widget.themeColor,
                provider: {
                  'id': otherUserId,
                  'name': name,
                  'profileUrl': photo,
                  'serviceName': service,
                  'title': service,
                },
              ),
            ),
          );
        }
      },
      onLongPress: () {
        if (!isSelectionMode) {
          setState(() {
            isSelectionMode = true;
            selectedChatIds.add(chatId);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        color: isSelected ? widget.themeColor.withValues(alpha: 0.05) : Colors.transparent,
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? widget.themeColor : Colors.grey.shade300,
                    width: 2,
                  ),
                  color: isSelected ? widget.themeColor : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ],
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty 
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black54)) 
                : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.isNotEmpty) ...[
                    Text(
                      service,
                      style: GoogleFonts.outfit(
                        color: widget.themeColor.withValues(alpha: 0.8), 
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: unreadCount > 0 ? Colors.black87 : Colors.black45, 
                      fontSize: 13,
                      fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: GoogleFonts.outfit(color: Colors.black45, fontSize: 12),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
