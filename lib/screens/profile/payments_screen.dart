import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_card_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final Color themeColor;
  const PaymentsScreen({super.key, required this.themeColor});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String selectedMethod = 'card_0'; // Default to first saved card if any
  List<Map<String, dynamic>> savedCards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedCards();
  }

  Future<void> _fetchSavedCards() async {
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .get();
      
      setState(() {
        savedCards = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching cards: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Payments",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose the payment method you'd like to use.",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const SizedBox(height: 12),
                  
                  // 🔹 SAVED CARDS
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ...savedCards.map((card) => _buildPaymentMethod(
                      id: card['id'],
                      icon: Icons.credit_card_rounded,
                      label: "**** **** **** ${card['last4']}",
                      iconColor: widget.themeColor,
                    )),
                    
                    const SizedBox(height: 24),
                    
                    // 🔹 ADD NEW CARD BUTTON
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddCardScreen(themeColor: widget.themeColor),
                          ),
                        );
                        if (result == true) {
                          _fetchSavedCards();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: widget.themeColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Add New Card",
                              style: GoogleFonts.outfit(
                                color: widget.themeColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 🔹 BOTTOM ACTION BUTTON
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: ElevatedButton(
              onPressed: () {
                // Confirm selection
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                "Next",
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod({
    required String id,
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    bool isSelected = selectedMethod == id;
    
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? widget.themeColor : Colors.grey.shade100,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.themeColor : Colors.grey.shade300,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
