import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_address_screen.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('addresses')
          .orderBy('isDefault', descending: true)
          .get();
      
      List<Map<String, dynamic>> fetched = snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();

      // Migration: if no addresses in subcollection, check the main address field
      if (fetched.isEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        final mainAddress = userDoc.data()?['address'] as String?;
        if (mainAddress != null && mainAddress.isNotEmpty) {
          // Create the first entry in subcollection automatically
          final newDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('addresses')
              .add({
            'label': 'Home',
            'address': mainAddress,
            'isDefault': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          fetched = [{
            'id': newDoc.id,
            'label': 'Home',
            'address': mainAddress,
            'isDefault': true,
          }];
        }
      }

      setState(() {
        _addresses = fetched;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching addresses: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(String id, bool isDefault) async {
    if (isDefault && _addresses.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot delete default address. Set another one as default first.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('addresses')
          .doc(id)
          .delete();
      _fetchAddresses();
    } catch (e) {
      debugPrint("Error deleting address: $e");
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
          "My Addresses",
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : Column(
              children: [
                Expanded(
                  child: _addresses.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _addresses.length,
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            return _buildAddressCard(address);
                          },
                        ),
                ),
                _buildAddButton(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No addresses saved yet",
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    bool isDefault = address['isDefault'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? Colors.grey.shade300 : Colors.grey.shade100,
          width: isDefault ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddAddressScreen(
                initialData: address,
                addressId: address['id'],
              ),
            ),
          );
          if (result == true) _fetchAddresses();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDefault 
                      ? Colors.grey.shade100 
                      : Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDefault ? Icons.home_rounded : Icons.location_on_outlined,
                  color: isDefault ? Colors.grey.shade600 : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address['label'] ?? 'Address',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "DEFAULT",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFF6B00),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address['address'] ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                onSelected: (val) {
                  if (val == 'delete') {
                    _deleteAddress(address['id'], isDefault);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text("Delete", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddAddressScreen()),
              );
              if (result == true) _fetchAddresses();
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              "Add New Address",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}
