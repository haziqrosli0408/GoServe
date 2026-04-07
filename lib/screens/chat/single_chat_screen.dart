import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SingleChatScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  const SingleChatScreen({super.key, required this.provider});

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;
  late final String chatId;

  @override
  void initState() {
    super.initState();
    _generateChatId();
  }

  void _generateChatId() {
    if (currentUser == null) return;
    final String providerId = widget.provider['providerId'] ?? widget.provider['id'] ?? '';
    final List<String> ids = [currentUser!.uid, providerId];
    ids.sort(); // Sort to ensure same ID regardless of who starts
    chatId = ids.join('_');
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

    // Update main chat doc for summary/sorting
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [currentUser!.uid, providerId],
      'users': {
        currentUser!.uid: {
          'name': currentUser!.displayName ?? 'User',
          'photo': currentUser!.photoURL ?? '',
        },
        providerId: {
          'name': providerName,
          'photo': widget.provider['providerProfileUrl'] ?? widget.provider['profileUrl'] ?? '',
        }
      }
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
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
                ? Text(providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P', style: GoogleFonts.outfit(color: const Color(0xFF1F212C), fontSize: 12, fontWeight: FontWeight.bold)) 
                : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text("Online", style: GoogleFonts.outfit(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

                final docs = snapshot.data!.docs;
                
                // Auto scroll on new message
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == currentUser?.uid;
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
                              color: isMe ? const Color(0xFFFF6B00) : const Color(0xFFF1F5F9),
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
            ),
          ),

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
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00),
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
