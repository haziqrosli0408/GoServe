import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_success_screen.dart';

class PaymentPage extends StatefulWidget {
  final String providerName;
  final String providerId;
  final String serviceName;
  final String serviceImage;
  final String category;
  final DateTime selectedDate;
  final String selectedTime;
  final double basePrice;
  final List<Map<String, dynamic>> selectedAddOns;
  final String address;
  final double totalPrice;

  const PaymentPage({
    super.key,
    required this.providerName,
    required this.providerId,
    required this.serviceName,
    required this.serviceImage,
    required this.category,
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
  String? selectedBank;
  final List<String> banks = [
    'Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank', 'Hong Leong Bank',
    'AmBank', 'UOB Bank', 'Bank Rakyat', 'Bank Islam', 'OCBC Bank',
    'HSBC Bank', 'Alliance Bank', 'Affin Bank', 'Standard Chartered'
  ];
  final Map<String, String> bankDomains = {
    'Maybank': 'maybank.com.my',
    'CIMB Bank': 'cimb.com.my',
    'Public Bank': 'pbebank.com',
    'RHB Bank': 'rhbgroup.com',
    'Hong Leong Bank': 'hlb.com.my',
    'AmBank': 'ambankgroup.com',
    'UOB Bank': 'uob.com.my',
    'Bank Rakyat': 'bankrakyat.com.my',
    'Bank Islam': 'bankislam.com.my',
    'OCBC Bank': 'ocbc.com.my',
    'HSBC Bank': 'hsbc.com.my',
    'Alliance Bank': 'alliancebank.com.my',
    'Affin Bank': 'affinbank.com.my',
    'Standard Chartered': 'sc.com'
  };
  final Color primaryGreen = const Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Payment', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Method', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            _buildPaymentMethodTile('Credit / Debit Card', 'Visa, Mastercard, AMEX', Icons.credit_card, 'card'),
            _buildPaymentMethodTile('Online Banking (FPX)', 'All Malaysian major banks supported', Icons.account_balance, 'fpx'),
            _buildPaymentMethodTile('E-Wallet', 'GrabPay, TNG eWallet, Boost', Icons.wallet_outlined, 'wallet'),
            
            if (selectedMethod == 'card') ...[
              const SizedBox(height: 24),
              _buildCardForm(),
            ],

            if (selectedMethod == 'fpx') ...[
              const SizedBox(height: 24),
              _buildFPXForm(),
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
                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
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
                  Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
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

  Widget _buildFPXForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formLabel('CHOOSE YOUR BANK'),
          GestureDetector(
            onTap: () => _showBankPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    children: [
                      if (selectedBank != null) ...[
                        Container(
                          width: 24, height: 24,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: const Color(0xFFF1F5F9)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              'https://logo.clearbit.com/${bankDomains[selectedBank]}',
                              errorBuilder: (context, error, stackTrace) => Center(child: Text(selectedBank![0], style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: primaryGreen))),
                            ),
                          ),
                        ),
                      ],
                      Text(
                        selectedBank ?? 'Select your bank',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: selectedBank == null ? Colors.grey.shade400 : Colors.black87,
                          fontWeight: selectedBank == null ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You will be redirected to your bank login page to complete the payment.',
            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  void _showBankPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Select Bank', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: banks.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final bank = banks[index];
                  final isSelected = selectedBank == bank;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.network(
                            'https://logo.clearbit.com/${bankDomains[bank]}',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(bank[0], style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: primaryGreen)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(bank, style: GoogleFonts.outfit(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: const Color(0xFF1E293B))),
                    trailing: isSelected ? Icon(Icons.check_circle, color: primaryGreen, size: 20) : null,
                    onTap: () {
                      setState(() => selectedBank = bank);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
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
              Text('Save card details for future bookings', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5)),
    );
  }

  Widget _formField(String hint, {Widget? suffix}) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffix,
      ),
      style: GoogleFonts.outfit(fontSize: 14),
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
              style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), height: 1.4),
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
          Text('Booking Summary', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(widget.serviceImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.serviceName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(widget.category, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_month, size: 14, color: primaryGreen),
                        const SizedBox(width: 6),
                        Text('${DateFormat('E, dd MMM').format(widget.selectedDate)} • ${widget.selectedTime}', style: GoogleFonts.outfit(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('SERVICE LOCATION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 16, color: const Color(0xFF1E293B)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.address, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E293B)))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _summaryRow('Service Price', 'RM ${widget.basePrice.toStringAsFixed(2)}'),
          ...widget.selectedAddOns.map((item) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _summaryRow('Add-on: ${item['name']}', 'RM ${((item['price'] is String ? double.tryParse(item['price']) : (item['price'] as num).toDouble()) ?? 0.0).toStringAsFixed(2)}'),
          )),
          const SizedBox(height: 12),
          _summaryRow('Charge Fee (15%)', 'RM ${(widget.totalPrice - widget.basePrice - widget.selectedAddOns.fold(0.0, (total, item) => total + ((item['price'] is String ? double.tryParse(item['price']) : (item['price'] as num).toDouble()) ?? 0.0))).toStringAsFixed(2)}'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL AMOUNT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('RM ${widget.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                child: Text('INSTANT CONFIRM', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32))),
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
        Text(label, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
        Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
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
            Text('Confirm & Pay', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
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
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'serviceName': widget.serviceName,
        'category': widget.category,
        'serviceImage': widget.serviceImage,
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'time': widget.selectedTime,
        'address': widget.address,
        'basePrice': widget.basePrice,
        'chargeFee': widget.totalPrice - widget.basePrice - widget.selectedAddOns.fold(0.0, (total, item) => total + ((item['price'] is String ? double.tryParse(item['price']) : (item['price'] as num).toDouble()) ?? 0.0)),
        'totalPrice': widget.totalPrice,
        'selectedAddOns': widget.selectedAddOns,
        'paymentMethod': selectedMethod,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              providerName: widget.providerName,
              serviceName: widget.serviceName,
              date: widget.selectedDate,
              time: widget.selectedTime,
              totalPrice: widget.totalPrice,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error processing payment')));
    }
  }
}
