import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? addressId;

  const AddAddressScreen({super.key, this.initialData, this.addressId});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _labelController = TextEditingController(); // e.g. Home, Office
  
  bool _isSaving = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final address = widget.initialData!['address'] as String? ?? '';
      final parts = address.split(',').map((e) => e.trim()).toList();
      if (parts.isNotEmpty) _unitController.text = parts[0];
      if (parts.length > 1) _streetController.text = parts[1];
      if (parts.length > 2) _postcodeController.text = parts[2];
      if (parts.length > 3) _stateController.text = parts.sublist(3).join(', ');
      
      _labelController.text = widget.initialData!['label'] ?? '';
      _isDefault = widget.initialData!['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _unitController.dispose();
    _streetController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_streetController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Street address is required")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final fullAddress = [
          _unitController.text.trim(),
          _streetController.text.trim(),
          _postcodeController.text.trim(),
          _stateController.text.trim(),
        ].where((e) => e.isNotEmpty).join(', ');

        final addressData = {
          'label': _labelController.text.trim().isEmpty ? 'Address' : _labelController.text.trim(),
          'address': fullAddress,
          'isDefault': _isDefault,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses');

        if (widget.addressId != null) {
          await collection.doc(widget.addressId).update(addressData);
        } else {
          // If first address, make it default
          final count = await collection.count().get();
          if (count.count == 0) addressData['isDefault'] = true;
          
          await collection.add(addressData);
        }

        // Also update the main user document for compatibility with other screens
        if (_isDefault || widget.addressId == null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'address': fullAddress,
          });
        }
        
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving address: $e")),
      );
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
          widget.addressId == null ? "Add New Address" : "Edit Address",
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddressField(
              label: "Label (e.g. Home, Office)",
              hint: "Home",
              controller: _labelController,
            ),
            const SizedBox(height: 16),
            _buildAddressField(
              label: "Unit / House No.",
              hint: "e.g. A-12-3 or No. 15",
              controller: _unitController,
            ),
            const SizedBox(height: 16),
            _buildAddressField(
              label: "Street Address",
              hint: "e.g. Jalan Ampang",
              controller: _streetController,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAddressField(
                    label: "Postcode",
                    hint: "50450",
                    controller: _postcodeController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAddressField(
                    label: "State",
                    hint: "Selangor",
                    controller: _stateController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Switch.adaptive(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  activeColor: const Color(0xFFFF6B00),
                ),
                const SizedBox(width: 8),
                Text(
                  "Set as default address",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        "Save Address",
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
