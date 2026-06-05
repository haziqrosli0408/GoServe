import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCardScreen extends StatefulWidget {
  final Color themeColor;
  const AddCardScreen({super.key, required this.themeColor});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  
  bool _saveCard = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    value = value.replaceAll(RegExp(r'\D'), '');
    var buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      buffer.write(value[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != value.length) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  Future<void> _saveCardToFirestore() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final last4 = _cardNumberController.text.replaceAll(' ', '').substring(
        _cardNumberController.text.replaceAll(' ', '').length - 4
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cards')
          .add({
        'holderName': _holderNameController.text,
        'last4': last4,
        'expiry': _expiryController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error saving card: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save card. Please try again.")),
        );
      }
    } finally {
      setState(() => _isSaving = false);
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
          "Add New Card",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 VISUAL CARD REPRESENTATION
              _buildVisualCard(),
              
              const SizedBox(height: 32),
              
              // 🔹 CARD NUMBER
              _buildFieldLabel("Card Number"),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500),
                onChanged: (val) {
                  setState(() {
                    String formatted = _formatCardNumber(val);
                    _cardNumberController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  });
                },
                decoration: _buildInputDecoration("1234 5678 9000 0000", Icons.credit_card_rounded),
                validator: (v) => (v == null || v.length < 19) ? "Enter valid card number" : null,
              ),
              
              const SizedBox(height: 20),
              
              // 🔹 HOLDER NAME
              _buildFieldLabel("Account Holder Name"),
              TextFormField(
                controller: _holderNameController,
                style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500),
                onChanged: (val) => setState(() {}),
                decoration: _buildInputDecoration("Wahid Khan Lohani", Icons.person_outline),
                validator: (v) => (v == null || v.isEmpty) ? "Enter holder name" : null,
              ),
              
              const SizedBox(height: 20),
              
              // 🔹 EXPIRY & CVV
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel("Expiry Date"),
                        TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500),
                          onChanged: (val) {
                            if (val.length == 2 && !_expiryController.text.contains('/')) {
                              _expiryController.text = '$val/';
                              _expiryController.selection = TextSelection.collapsed(offset: 3);
                            }
                            setState(() {});
                          },
                          maxLength: 5,
                          decoration: _buildInputDecoration("MM/YY", Icons.calendar_today_outlined),
                          validator: (v) => (v == null || v.length < 5) ? "Invalid" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel("CVV"),
                        TextFormField(
                          controller: _cvvController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 3,
                          style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500),
                          onChanged: (val) => setState(() {}),
                          decoration: _buildInputDecoration("123", Icons.lock_outline),
                          validator: (v) => (v == null || v.length < 3) ? "Invalid" : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 🔹 SAVE TOGGLE
              Row(
                children: [
                  Checkbox(
                    value: _saveCard,
                    onChanged: (v) => setState(() => _saveCard = v ?? true),
                    activeColor: widget.themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Text(
                    "Save Card Information",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // 🔹 SAVE BUTTON
              ElevatedButton(
                onPressed: _isSaving ? null : _saveCardToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Save",
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualCard() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.themeColor,
            widget.themeColor.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Debit",
                style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
              ),
              const Icon(Icons.contactless, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _cardNumberController.text.isEmpty ? "XXXX XXXX XXXX XXXX" : _cardNumberController.text,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CARD HOLDER",
                    style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                  ),
                  Text(
                    _holderNameController.text.isEmpty ? "YOUR NAME" : _holderNameController.text.toUpperCase(),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EXPIRES",
                    style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                  ),
                  Text(
                    _expiryController.text.isEmpty ? "MM/YY" : _expiryController.text,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w400),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      counterText: "",
    );
  }
}
