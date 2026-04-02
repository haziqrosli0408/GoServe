import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SingleChatScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  const SingleChatScreen({super.key, required this.provider});

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  late final List<Map<String, dynamic>> messages;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 🔹 MOCK INITIAL MESSAGES
    messages = [
      {
        "text": "Hi, I'm on my way to your location now!",
        "isMe": false,
        "time": "2:10 PM",
      },
      {
        "text": "Great! See you soon.",
        "isMe": true,
        "time": "2:12 PM",
      },
    ];
  }

  void sendMessage() {
    if (messageController.text.trim().isEmpty) return;

    setState(() {
      messages.add({
        "text": messageController.text.trim(),
        "isMe": true,
        "time": TimeOfDay.now().format(context),
      });
      messageController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    String providerName = widget.provider['name'] ?? 'Provider';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$providerName'),
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
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final msg = messages[index];
                bool isMe = msg['isMe'] ?? true;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFF6B00) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text'],
                          style: GoogleFonts.outfit(
                            color: isMe ? Colors.white : const Color(0xFF1F212C),
                            fontSize: 14,
                            fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          msg['time'],
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
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
