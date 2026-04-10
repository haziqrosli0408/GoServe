import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SingleChatScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final Color themeColor;
  final String? chatId;
  const SingleChatScreen({
    super.key, 
    required this.provider, 
    this.themeColor = const Color(0xFFFF6B00),
    this.chatId,
  });

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;
  late final String chatId;
  String? currentUserName;
  String? currentUserPhoto;

  @override
  void initState() {
    super.initState();
    _generateChatId();
    _fetchCurrentUserProfile();
    _resetUnreadCount();
  }

  Future<void> _resetUnreadCount() async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'unreadCount': {
        currentUser!.uid: 0,
      }
    }, SetOptions(merge: true));
  }

  Future<void> _fetchCurrentUserProfile() async {
    if (currentUser == null) return;
    
    // Try fetching from users collection first
    var doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    
    // If not found, try providers collection
    if (!doc.exists) {
      doc = await FirebaseFirestore.instance.collection('providers').doc(currentUser!.uid).get();
    }
    
    if (doc.exists && mounted) {
      setState(() {
        currentUserName = doc.data()?['name'];
        currentUserPhoto = doc.data()?['profileUrl'];
      });
      // Sync names and photos into the chat metadata for instant loading in chat list
      _syncMetadata();
    }
  }

  Future<void> _syncMetadata() async {
    if (currentUser == null) return;
    final String providerId = widget.provider['id'] ?? widget.provider['providerId'] ?? '';
    final String providerName = widget.provider['name'] ?? widget.provider['providerName'] ?? 'Provider';

    final String serviceTitle = widget.provider['title'] ?? widget.provider['serviceName'] ?? widget.provider['category'] ?? 'Service';

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': FieldValue.arrayUnion([currentUser!.uid, providerId]),
      'serviceTitle': serviceTitle,
      'users': {
        currentUser!.uid: {
          'name': currentUserName ?? currentUser!.displayName ?? 'User',
          'photo': currentUserPhoto ?? currentUser!.photoURL ?? '',
        },
        providerId: {
          'name': providerName,
          'photo': widget.provider['profileUrl'] ?? widget.provider['providerProfileUrl'] ?? '',
          'serviceName': widget.provider['title'] ?? widget.provider['category'] ?? widget.provider['serviceName'] ?? '',
        }
      }
    }, SetOptions(merge: true));
  }

  void _generateChatId() {
    if (widget.chatId != null) {
      chatId = widget.chatId!;
      return;
    }
    if (currentUser == null) return;
    final String providerId = widget.provider['providerId'] ?? widget.provider['id'] ?? '';
    final String serviceId = widget.provider['serviceId'] ?? '';
    
    // Sort identifiers to ensure the same Chat ID regardless of who initiates
    final List<String> identifiers = [currentUser!.uid, providerId];
    if (serviceId.isNotEmpty) {
      identifiers.add(serviceId);
    }
    
    identifiers.sort();
    chatId = identifiers.join('_');
  }

  Future<void> sendMessage() async {
    final String text = messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final String providerId = widget.provider['providerId'] ?? widget.provider['id'] ?? '';
    final String providerName = widget.provider['providerName'] ?? widget.provider['name'] ?? 'Provider';

    messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'receiverId': providerId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final String serviceTitle = widget.provider['title'] ?? widget.provider['serviceName'] ?? widget.provider['category'] ?? 'Service';

    // Update main chat doc for summary/sorting
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [currentUser!.uid, providerId],
      'serviceTitle': serviceTitle,
      'users': {
        currentUser!.uid: {
          'name': currentUserName ?? currentUser!.displayName ?? 'User',
          'photo': currentUserPhoto ?? currentUser!.photoURL ?? '',
        },
        providerId: {
          'name': providerName,
          'photo': widget.provider['providerProfileUrl'] ?? widget.provider['profileUrl'] ?? '',
          'serviceName': widget.provider['title'] ?? widget.provider['category'] ?? widget.provider['serviceName'] ?? (widget.provider['services'] is List && (widget.provider['services'] as List).isNotEmpty ? widget.provider['services'][0] : ''),
        }
      },
      'unreadCount': {
        providerId: FieldValue.increment(1),
      },
      'deletedBy': [], // Show back for everyone as requested
      'archivedBy': [],
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String providerName = widget.provider['providerName'] ?? widget.provider['name'] ?? 'Provider';
    final String providerPhoto = widget.provider['providerProfileUrl'] ?? widget.provider['profileUrl'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: providerPhoto.isNotEmpty ? NetworkImage(providerPhoto) : null,
              child: providerPhoto.isEmpty 
                ? Text(providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 12, fontWeight: FontWeight.w600)) 
                : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text("Online", style: GoogleFonts.outfit(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            )
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
              builder: (context, chatSnapshot) {
                final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;
                final Timestamp? clearedAt = chatData?['clearedAt'] as Timestamp?;

                return MessageList(
                  chatId: chatId, 
                  clearedAt: clearedAt, 
                  currentUser: currentUser, 
                  scrollController: scrollController,
                  scrollToBottom: _scrollToBottom,
                  themeColor: widget.themeColor,
                );
              },
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // 🔹 Bottom Input Section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: messageController,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.themeColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class MessageList extends StatefulWidget {
  final String chatId;
  final Timestamp? clearedAt;
  final User? currentUser;
  final ScrollController scrollController;
  final VoidCallback scrollToBottom;
  final Color themeColor;

  const MessageList({
    super.key,
    required this.chatId,
    required this.clearedAt,
    required this.currentUser,
    required this.scrollController,
    required this.scrollToBottom,
    required this.themeColor,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  Stream<QuerySnapshot>? _messageStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      _initStream();
    }
  }

  void _initStream() {
    setState(() {
      _messageStream = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_messageStream == null) {
      return Center(child: CircularProgressIndicator(color: widget.themeColor));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: widget.themeColor));
        }

        final allMessages = snapshot.data?.docs ?? [];
        final filteredDocs = allMessages.where((doc) {
          final ts = (doc.data() as Map)['timestamp'] as Timestamp?;
          if (widget.clearedAt == null) return true;
          if (ts == null) return true;
          return ts.compareTo(widget.clearedAt!) > 0;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "No messages yet.\nSay hi to start the conversation!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: widget.scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          itemCount: filteredDocs.length,
          itemBuilder: (_, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final bool isMe = data['senderId'] == widget.currentUser?.uid;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            final String time = ts != null ? DateFormat('h:mm a').format(ts.toDate()) : '';

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? widget.themeColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      data['text'] ?? '',
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        time,
                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
