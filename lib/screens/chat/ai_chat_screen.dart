import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/service_details.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late GenerativeModel _model;
  late ChatSession _chatSession;
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _userState = '';

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    _initializeChat();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final address = doc.data()?['address']?.toString() ?? 'Kuala Lumpur, Malaysia';
          if (address.isNotEmpty) {
            if (address.contains(',')) {
              final parts = address.split(',');
              if (parts.length >= 2) {
                if (mounted) {
                  setState(() {
                    _userState = parts[parts.length - 2].trim().toLowerCase();
                  });
                }
              }
            } else {
              if (mounted) {
                setState(() {
                  _userState = address.toLowerCase();
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("AI Location error: $e");
    }
  }

  void _initializeChat() {
    // 1. Setup the Gemini Model with a robust System Prompt and Tool
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system('''
You are the GoServe AI Assistant, an expert customer support agent and home maintenance diagnostician for the GoServe app.
Always be extremely helpful, polite, concise, and professional. Keep answers short and direct.

FEATURE 1 - Problem Clarification (MANDATORY FIRST STEP):
When a user describes an issue or requests a service (e.g., "my aircon isn't cold", "my car is dirty", "leaking sink"), YOU MUST NEVER immediately recommend a service or use the `search_services` tool in your first reply.
Instead, you MUST FIRST ask 1 or 2 targeted diagnostic questions to clarify the issue and gather more details.
Example: If they say "my car is dirty", ask "Is it just the exterior, or does the interior need cleaning too?"
Wait for their response before suggesting a service.

FEATURE 2 - Smart Service Recommendation:
If you understand the user's problem and are ready to recommend a service, use the `search_services` tool.
Provide a clear search query (e.g., "Car wash", "Plumbing", "Cleaning", "Electrical", "Repairing").
After calling the tool, present the results to the user encouragingly. DO NOT list the services in text since they will be rendered as UI cards below your message. Just say something like "Here are some great options I found for you!"

FEATURE 3 - App Guide:
If the user asks how to use the GoServe app:
- To book: Find a service on the Home Screen, tap Book Now, select date/time and address.
- To cancel: Go to Bookings -> Upcoming tab -> select your booking -> tap Cancel.
- To reschedule: Go to Bookings -> Upcoming tab -> select your booking -> tap the orange "Reschedule" button at the bottom.
- Statuses: Pending (waiting for provider), Confirmed (provider accepted), In Progress, Completed, Cancelled.

FEATURE 4 - FAQ & Policies:
- Late Provider: If a provider is more than 15 minutes late, tell the user to call them directly or contact support via Live Chat.
- Reschedule Policy: Rescheduling within 24 hours of the service may incur a fee.
- Cancel Policy: Free cancellations are available up to 24 hours before the service starts. Users can cancel from the tracking screen.
- Wrong Address: If the provider is at the wrong address, tell the user to use the chat button on the tracking screen to send their correct location or a photo of their house entrance.
      '''),
      tools: [
        Tool.functionDeclarations([
          FunctionDeclaration(
            'search_services',
            'Search the GoServe database for services matching a query keyword.',
            parameters: {
              'query': Schema.string(
                description: 'A specific keyword to search for (e.g. "car wash", "plumbing", "cleaning").',
              ),
            },
          ),
        ]),
      ],
    );
    
    // Start a fresh chat session
    _chatSession = _model.startChat();
    
    // Add a welcome message from the AI
    _messages.add({
      'role': 'assistant',
      'text': 'Hello! I am your GoServe Assistant. How can I help you today? E.g., describe an issue with your home or ask how to use the app.',
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
      });
      _isLoading = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      
      // Handle Function Calling
      if (response.functionCalls.isNotEmpty) {
        for (final call in response.functionCalls) {
          if (call.name == 'search_services') {
            final query = call.args['query'] as String?;
            
            // Query Firestore
            final snapshot = await FirebaseFirestore.instance
                .collection('services')
                .where('isActive', isEqualTo: true)
                .get();
                
            final results = snapshot.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).where((s) {
              final cat = (s['category'] as String?)?.toLowerCase() ?? '';
              final title = (s['title'] as String?)?.toLowerCase() ?? '';
              final providerAddress = (s['providerAddress'] as String?)?.toLowerCase() ?? '';
              final q = query?.toLowerCase().trim() ?? '';
              
              // 1. Filter by location first
              if (_userState.isNotEmpty && !providerAddress.contains(_userState)) {
                return false;
              }
              
              // 2. Exact match first
              if (cat.contains(q) || title.contains(q)) return true;
              
              // 3. Split by words and check for any match (for words > 2 chars)
              final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
              for (final word in words) {
                if (cat.contains(word) || title.contains(word)) return true;
              }
              
              return false;
            }).take(5).toList();

            // Pass results back to Gemini so it can generate a final text response
            final functionResponse = await _chatSession.sendMessage(
              Content.functionResponse(
                call.name, 
                {'status': 'success', 'count': results.length}
              )
            );

            setState(() {
              _messages.add({
                'role': 'assistant',
                'text': functionResponse.text ?? "I found these services for you!",
                'services': results, // Store raw data to render UI cards
              });
              _isLoading = false;
            });
          }
        }
      } else {
        // Normal text response
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': response.text ?? "I'm sorry, I couldn't process that request.",
          });
          _isLoading = false;
        });
      }
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': 'Error: $e',
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black87),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFF6B00), size: 20),
            const SizedBox(width: 8),
            Text(
              'GoServe AI',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['role'] == 'user';
                final services = message['services'] as List<dynamic>?;
                
                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _buildMessageBubble(
                      text: message['text'],
                      isUser: isUser,
                    ),
                    if (services != null && services.isNotEmpty)
                      _buildServicesList(services),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
               padding: const EdgeInsets.only(left: 20, bottom: 10),
               child: Align(
                 alignment: Alignment.centerLeft,
                 child: Row(
                   children: [
                     const SizedBox(
                       width: 15,
                       height: 15,
                       child: CircularProgressIndicator(
                         strokeWidth: 2,
                         valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                       ),
                     ),
                     const SizedBox(width: 10),
                     Text(
                       'Thinking...',
                       style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                     ),
                   ],
                 ),
               ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFFF6B00) : Colors.grey[100],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 0),
          bottomRight: Radius.circular(isUser ? 0 : 20),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildServicesList(List<dynamic> services) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 4),
      child: Column(
        children: services.map((s) => _buildAICard(s as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Widget _buildAICard(Map<String, dynamic> service) {
    final title = service['title'] ?? 'Service';
    final providerName = service['providerName'] ?? 'Provider';
    final price = service['price']?.toString() ?? '0';
    final imageUrl = service['servicePhotoUrl'] ?? '';
    final ratingValue = (service['averageRating'] ?? 0).toDouble();
    final reviewsCount = service['reviewCount'] ?? 0;
    final ratingLabel = ratingValue == 0 ? "New" : "${ratingValue.toStringAsFixed(1)} ($reviewsCount)";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ServiceDetailsScreen(provider: service)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.network(
                  'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=800&auto=format&fit=crop', 
                  width: 90, 
                  height: 90, 
                  fit: BoxFit.cover
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          ratingLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey.shade400, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            providerName,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'RM$price',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF6B00),
                            ),
                          ),
                          if (service['priceType'] != 'one-time')
                            TextSpan(
                              text: '/hr',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _isLoading ? Colors.grey[300] : const Color(0xFFFF6B00),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
