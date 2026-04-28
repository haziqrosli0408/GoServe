import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();

  String _selectedMethod = 'Bank';
  String? _defaultBank = 'Maybank';
  String? _defaultEWallet = 'Touch \'n Go';

  final List<String> _banks = ['Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank', 'Hong Leong Bank'];
  final List<String> _eWallets = ['Touch \'n Go', 'DuitNow', 'GrabPay', 'Boost'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cardNumberController.dispose();
    _cvvController.dispose();
    _expiryController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: "Methods"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMethodsTab(),
          _buildHistoryTab(),
        ],
      ),
      bottomNavigationBar: _tabController.index == 0 ? _buildSaveButton() : null,
    );
  }

  Widget _buildMethodsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Choose your method"),
          const SizedBox(height: 16),
          _buildMethodTile(
            title: "Online Banking",
            subtitle: _defaultBank ?? "Select your bank",
            icon: Icons.account_balance_rounded,
            method: 'Bank',
          ),
          const SizedBox(height: 12),
          _buildMethodTile(
            title: "Debit / Credit Card",
            subtitle: "Visa, Mastercard, AMEX",
            icon: Icons.credit_card_rounded,
            method: 'Card',
          ),
          const SizedBox(height: 12),
          _buildMethodTile(
            title: "E-Wallet",
            subtitle: _defaultEWallet ?? "Select provider",
            icon: Icons.account_balance_wallet_rounded,
            method: 'E-Wallet',
          ),
          const SizedBox(height: 32),
          _buildMethodDetails(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildMethodTile({required String title, required String subtitle, required IconData icon, required String method}) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B00).withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B00) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6B00) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6B00), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodDetails() {
    if (_selectedMethod == 'Bank') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Default Bank"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _banks.map((bank) {
              bool isDefault = _defaultBank == bank;
              return ChoiceChip(
                label: Text(bank),
                selected: isDefault,
                onSelected: (selected) {
                  if (selected) setState(() => _defaultBank = bank);
                },
                selectedColor: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                labelStyle: GoogleFonts.outfit(
                  color: isDefault ? const Color(0xFFFF6B00) : Colors.grey.shade700,
                  fontWeight: isDefault ? FontWeight.w600 : FontWeight.w500,
                ),
                backgroundColor: Colors.grey.shade50,
                side: BorderSide(color: isDefault ? const Color(0xFFFF6B00) : Colors.grey.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
        ],
      );
    } else if (_selectedMethod == 'Card') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Card Information"),
          const SizedBox(height: 16),
          _buildTextField(controller: _cardNumberController, label: "Card Number", hint: "0000 0000 0000 0000", icon: Icons.credit_card),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(controller: _expiryController, label: "Expiry Date", hint: "MM/YY")),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(controller: _cvvController, label: "CVV", hint: "123", isSecure: true)),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Default E-Wallet"),
          const SizedBox(height: 12),
          Row(
            children: _eWallets.take(2).map((wallet) {
              bool isDefault = _defaultEWallet == wallet;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _defaultEWallet = wallet),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDefault ? const Color(0xFFFF6B00).withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDefault ? const Color(0xFFFF6B00) : Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        wallet,
                        style: GoogleFonts.outfit(
                          fontWeight: isDefault ? FontWeight.w600 : FontWeight.w500,
                          color: isDefault ? const Color(0xFFFF6B00) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }
  }

  Widget _buildTextField({required TextEditingController controller, required String label, String? hint, IconData? icon, bool isSecure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            obscureText: isSecure,
            style: GoogleFonts.outfit(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade400, size: 20) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _mockHistory.length,
      itemBuilder: (context, index) {
        final item = _mockHistory[index];
        bool isMoneyIn = item['type'] == 'In';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMoneyIn ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMoneyIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isMoneyIn ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      item['date'],
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isMoneyIn ? '+' : '-'} RM${item['amount']}",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isMoneyIn ? Colors.green : const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['status'],
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(item['status']),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'Pending': return Colors.orange;
      case 'Failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Payment settings updated!"), backgroundColor: Color(0xFFFF6B00)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              "Save Settings",
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  final List<Map<String, dynamic>> _mockHistory = [
    {'title': 'Aircond Service', 'date': '24 Oct 2023, 10:30 AM', 'amount': '150.00', 'type': 'Out', 'status': 'Completed'},
    {'title': 'Wallet Top-up', 'date': '22 Oct 2023, 02:15 PM', 'amount': '200.00', 'type': 'In', 'status': 'Completed'},
    {'title': 'House Cleaning', 'date': '20 Oct 2023, 09:00 AM', 'amount': '85.00', 'type': 'Out', 'status': 'Completed'},
    {'title': 'Plumbing Repair', 'date': '18 Oct 2023, 04:45 PM', 'amount': '120.00', 'type': 'Out', 'status': 'Pending'},
    {'title': 'Refund - Electrical', 'date': '15 Oct 2023, 11:20 AM', 'amount': '50.00', 'type': 'In', 'status': 'Completed'},
  ];
}
