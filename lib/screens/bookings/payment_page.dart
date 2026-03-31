import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentPage extends StatefulWidget {
  final String providerName;
  final String serviceName;
  final DateTime selectedDate;
  final String selectedTime;
  final double basePrice;
  final List<Map<String, dynamic>> selectedAddOns;
  final String address;
  final double totalPrice;

  const PaymentPage({
    super.key,
    required this.providerName,
    required this.serviceName,
    required this.selectedDate,
    required this.selectedTime,
    required this.basePrice,
    required this.selectedAddOns,
    required this.address,
    required this.totalPrice,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String selectedMethod = 'card';
  final Color primaryGreen = const Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Payment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Method', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            _buildPaymentMethodTile('Credit / Debit Card', 'Visa, Mastercard, AMEX', Icons.credit_card, 'card'),
            _buildPaymentMethodTile('Online Banking (FPX)', 'All Malaysian major banks supported', Icons.account_balance, 'fpx'),
            _buildPaymentMethodTile('E-Wallet', 'GrabPay, TNG eWallet, Boost', Icons.wallet_outlined, 'wallet'),
            
            if (selectedMethod == 'card') ...[
              const SizedBox(height: 24),
              _buildCardForm(),
            ],

            const SizedBox(height: 24),
            _buildSecurityNotice(),

            const SizedBox(height: 32),
            _buildBookingSummary(),

            const SizedBox(height: 32),
            _buildFooterButton(),
            
            const SizedBox(height: 12),
            Center(
              child: Text(
                'By clicking \'Confirm & Pay\', you agree to our Terms of Service and Cancellation Policy.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String title, String subtitle, IconData icon, String method) {
    bool isSelected = selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryGreen : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300, width: 2),
              ),
              child: isSelected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle))) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formLabel('CARDHOLDER NAME'),
          _formField('e.g. AHMAD FAISAL'),
          const SizedBox(height: 20),
          _formLabel('CARD NUMBER'),
          _formField('0000 0000 0000 0000', suffix: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.credit_card, size: 16, color: Colors.grey.shade400)])),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_formLabel('EXPIRY DATE'), _formField('MM / YY')])),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_formLabel('CVV'), _formField('***')])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300))),
              const SizedBox(width: 10),
              Text('Save card details for future bookings', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
    );
  }

  Widget _formField(String hint, {Widget? suffix}) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffix,
      ),
      style: GoogleFonts.inter(fontSize: 14),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your transaction is secured with 256-bit SSL encryption. We do not store your full card details on our servers.',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Summary', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1581578731548-c64695cc6954?auto=format&fit=crop&q=80&w=300'), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.serviceName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text('Premium Service', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 14, color: primaryGreen),
                        const SizedBox(width: 6),
                        Text('${DateFormat('E, dd MMM').format(widget.selectedDate)} • ${widget.selectedTime}', style: GoogleFonts.inter(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('SERVICE LOCATION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 16, color: const Color(0xFF1E293B)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B)))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _summaryRow('Service Price', 'RM ${widget.basePrice.toStringAsFixed(2)}'),
          ...widget.selectedAddOns.map((item) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _summaryRow('Add-on: ${item['name']}', 'RM ${item['price'].toDouble().toStringAsFixed(2)}'),
          )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL AMOUNT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('RM ${widget.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                child: Text('INSTANT CONFIRM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildFooterButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _onPay,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Confirm & Pay', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _onPay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'customerId': user.uid,
        'providerName': widget.providerName,
        'serviceName': widget.serviceName,
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'time': widget.selectedTime,
        'address': widget.address,
        'totalPrice': widget.totalPrice,
        'paymentMethod': selectedMethod,
        'status': 'Confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context); 
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful! Booking Confirmed.')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error processing payment')));
    }
  }
}
