import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProviderEarningsPage extends StatefulWidget {
  const ProviderEarningsPage({super.key});

  @override
  State<ProviderEarningsPage> createState() => _ProviderEarningsPageState();
}

class _ProviderEarningsPageState extends State<ProviderEarningsPage> {
  final Color themeColor = const Color(0xFF4F46E5);
  final user = FirebaseAuth.instance.currentUser;
  
  double totalEarnings = 0;

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
    'Standard Chartered': 'sc.com',
  };

  void _showWithdrawModal() async {
    // Fetch provider bank details
    String? savedBank;
    String? savedAccount;
    String? providerEmail = user?.email;
    String providerName = 'Provider';

    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(user!.uid)
          .get();
      if (providerDoc.exists) {
        final data = providerDoc.data() as Map<String, dynamic>;
        savedBank = data['bankName'];
        savedAccount = data['accountNumber'];
        if (data['email'] != null) providerEmail = data['email'];
        if (data['name'] != null) providerName = data['name'];
      }
    } catch (_) {}

    if (!mounted) return;

    String? selectedBank = savedBank;
    final accountController = TextEditingController(text: savedAccount ?? '');
    final amountController = TextEditingController();
    bool showBankList = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedBankDomain = selectedBank != null ? bankDomains[selectedBank!] : null;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Withdraw Funds",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Available balance: RM ${totalEarnings.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount field
                  Text(
                    "Amount (RM)",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "0.00",
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          "RM",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeColor,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: themeColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank account
                  Text(
                    "Bank account",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setModalState(() => showBankList = !showBankList),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: showBankList
                            ? const BorderRadius.vertical(top: Radius.circular(14))
                            : BorderRadius.circular(14),
                        border: Border.all(color: showBankList ? themeColor : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          if (selectedBank != null && selectedBankDomain != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                "https://www.google.com/s2/favicons?sz=64&domain=$selectedBankDomain",
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 20),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (selectedBank == null)
                            Icon(Icons.account_balance_outlined, size: 20, color: Colors.grey[400]),
                          if (selectedBank == null)
                            const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedBank ?? "Choose your bank account",
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: selectedBank != null ? const Color(0xFF1E293B) : Colors.grey[400],
                                fontWeight: selectedBank != null ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(
                            showBankList ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bank dropdown list
                  if (showBankList)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        border: Border.all(color: themeColor),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: banks.length,
                        itemBuilder: (context, index) {
                          final bank = banks[index];
                          final domain = bankDomains[bank];
                          final isSelected = selectedBank == bank;
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedBank = bank;
                                showBankList = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: isSelected ? themeColor.withValues(alpha: 0.05) : null,
                              child: Row(
                                children: [
                                  if (domain != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        "https://www.google.com/s2/favicons?sz=64&domain=$domain",
                                        width: 20,
                                        height: 20,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 20),
                                      ),
                                    ),
                                  if (domain != null) const SizedBox(width: 12),
                                  Text(
                                    bank,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? themeColor : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Account number
                  Text(
                    "Account number",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Enter your bank account number",
                      prefixIcon: Icon(Icons.credit_card_outlined, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: themeColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Withdraw button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final amountText = amountController.text.trim();
                        final amount = double.tryParse(amountText);

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }
                        if (amount > totalEarnings) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Amount exceeds available balance')),
                          );
                          return;
                        }
                        if (selectedBank == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a bank')),
                          );
                          return;
                        }
                        if (accountController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your account number')),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        try {
                          // Artificial delay for better UX
                          await Future.delayed(const Duration(seconds: 1));

                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'providerId': user!.uid,
                            'amount': amount,
                            'bankName': selectedBank,
                            'accountNumber': accountController.text.trim(),
                            'status': 'Pending',
                            'requestedAt': FieldValue.serverTimestamp(),
                          });

                          // Also update bank details on provider profile if changed
                          await FirebaseFirestore.instance.collection('providers').doc(user!.uid).update({
                            'bankName': selectedBank,
                            'accountNumber': accountController.text.trim(),
                          });

                          // Send email notification
                          if (providerEmail != null && providerEmail.isNotEmpty) {
                            await FirebaseFirestore.instance.collection('mail').add({
                              'to': providerEmail,
                              'message': {
                                'subject': 'GoServe - Withdrawal Request Submitted',
                                'html': '''
                                  <h3>Hello $providerName,</h3>
                                  <p>Your withdrawal request for <strong>RM ${amount.toStringAsFixed(2)}</strong> has been successfully submitted.</p>
                                  <p><strong>Bank Details:</strong><br>
                                  Bank: $selectedBank<br>
                                  Account Number: ${accountController.text.trim()}</p>
                                  <p>Your funds will be transferred to your account soon.</p>
                                  <br>
                                  <p>Best regards,<br>The GoServe Team</p>
                                ''',
                              }
                            });
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Withdrawal of RM ${amount.toStringAsFixed(2)} submitted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setModalState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              "Withdraw",
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black87),
        title: Text(
          "Earnings",
          style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('providerId', isEqualTo: user!.uid)
                        .snapshots(),
                    builder: (context, bookingsSnapshot) {
                      if (bookingsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (bookingsSnapshot.hasError) {
                        return Center(child: Text("Error: ${bookingsSnapshot.error}"));
                      }
                      
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('withdrawals')
                            .where('providerId', isEqualTo: user!.uid)
                            .snapshots(),
                        builder: (context, withdrawalsSnapshot) {
                          if (withdrawalsSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (withdrawalsSnapshot.hasError) {
                            return Center(child: Text("Error: ${withdrawalsSnapshot.error}"));
                          }

                          var bookings = (bookingsSnapshot.data?.docs ?? [])
                              .map((doc) => doc.data() as Map<String, dynamic>)
                              .where((t) => ['Completed', 'Cancelled'].contains(t['status']))
                              .map((t) => {...t, 'type': 'booking'})
                              .toList();

                          var withdrawals = (withdrawalsSnapshot.data?.docs ?? [])
                              .map((doc) => doc.data() as Map<String, dynamic>)
                              .map((t) => {...t, 'type': 'withdrawal'})
                              .toList();

                          var transactions = [...bookings, ...withdrawals];

                          // Sort by date descending
                          transactions.sort((a, b) {
                            final aTime = (a['completedAt'] ?? a['createdAt'] ?? a['requestedAt']) as Timestamp?;
                            final bTime = (b['completedAt'] ?? b['createdAt'] ?? b['requestedAt']) as Timestamp?;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime);
                          });

                          // Calculate available balance
                          double calculatedTotal = 0;
                          for (var t in transactions) {
                            if (t['type'] == 'booking' && t['status'] == 'Completed') {
                              if (t['payoutStatus'] == 'transferred') {
                                final priceStr = (t['totalPrice'] ?? t['price'] ?? '0').toString().replaceAll('RM', '').trim();
                                calculatedTotal += double.tryParse(priceStr) ?? 0.0;
                              }
                            } else if (t['type'] == 'withdrawal') {
                              // Subtract withdrawals from available balance
                              final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                              calculatedTotal -= amount;
                            }
                          }

                          // Schedule state update after build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && totalEarnings != calculatedTotal) {
                              setState(() {
                                totalEarnings = calculatedTotal;
                              });
                            }
                          });

                          return CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(child: _buildSummaryCard()),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    "Transaction History",
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              if (transactions.isEmpty)
                                SliverToBoxAdapter(child: _buildEmptyState())
                              else
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildTransactionCard(transactions[index]);
                                    },
                                    childCount: transactions.length,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor, themeColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Available Balance",
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "RM ${totalEarnings.toStringAsFixed(2)}",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Available for withdrawal",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showWithdrawModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: themeColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Withdraw",
                        style: GoogleFonts.outfit(
                          color: themeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    if (transaction['type'] == 'withdrawal') {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      final status = transaction['status'] ?? 'Pending';
      final bankName = transaction['bankName'] ?? 'Bank';
      DateTime dt = DateTime.now();
      if (transaction['requestedAt'] != null) {
        dt = (transaction['requestedAt'] as Timestamp).toDate();
      }
      final dateStr = DateFormat('MMM d, yyyy').format(dt);
      final timeStr = DateFormat('h:mm a').format(dt);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Withdrawal",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "To: $bankName • $dateStr, $timeStr",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "- RM ${amount.toStringAsFixed(2)}",
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  status,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: status == 'Completed' ? Colors.green.shade600 : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final serviceName = transaction['serviceName'] ?? 'Unknown Service';
    final customerId = transaction['customerId'] ?? '';
    final status = transaction['status'] ?? '';
    final priceStr = (transaction['totalPrice'] ?? transaction['price'] ?? '0').toString().replaceAll('RM', '').trim();
    final totalPrice = double.tryParse(priceStr) ?? 0.0;
    double chargeFee = 0.0;
    if (transaction['chargeFee'] != null) {
      chargeFee = (transaction['chargeFee'] as num).toDouble();
    } else {
      chargeFee = totalPrice - (totalPrice / 1.15);
    }
    final amount = totalPrice - chargeFee;
    
    DateTime dt = DateTime.now();
    if (transaction['completedAt'] != null) {
      dt = (transaction['completedAt'] as Timestamp).toDate();
    } else if (transaction['createdAt'] != null) {
      dt = (transaction['createdAt'] as Timestamp).toDate();
    }
    
    final dateStr = DateFormat('MMM d, yyyy').format(dt);
    final timeStr = DateFormat('h:mm a').format(dt);

    final isRefund = status == 'Cancelled';
    final isPendingTransfer = status == 'Completed' && transaction['payoutStatus'] != 'transferred';
    final color = isRefund 
        ? Colors.red.shade600 
        : (isPendingTransfer ? Colors.amber.shade700 : Colors.green.shade600);
    final icon = isRefund 
        ? Icons.call_made 
        : (isPendingTransfer ? Icons.schedule_rounded : Icons.call_received);
    final prefix = isRefund ? "-" : "+";

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
      builder: (context, snapshot) {
        String customerName = transaction['customerName'] ?? 'Customer';

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          customerName = userData['name'] ?? customerName;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$customerName • $dateStr, $timeStr",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$prefix RM ${amount.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (isRefund)
                    Text(
                      "Refunded",
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (isPendingTransfer)
                    Text(
                      "Pending Transfer",
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.amber.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No transactions found",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "There are no earnings recorded yet.",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
