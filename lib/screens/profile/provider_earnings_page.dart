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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const BackButton(color: Colors.black87),
        title: Text(
          "Earnings",
          style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600),
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
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      var transactions = snapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .where((t) => ['Completed', 'Cancelled'].contains(t['status']))
                          .toList();

                      // Sort by createdAt descending
                      transactions.sort((a, b) {
                        final aTime = a['createdAt'] as Timestamp?;
                        final bTime = b['createdAt'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      // Calculate and filter
                      double calculatedTotal = 0;
                      for (var t in transactions) {
                        final priceStr = (t['totalPrice'] ?? t['price'] ?? '0').toString().replaceAll('RM', '').trim();
                        final amount = double.tryParse(priceStr) ?? 0.0;
                        
                        if (t['status'] == 'Completed') {
                          calculatedTotal += amount; // Gross amount
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
            "Gross Earnings (All Time)",
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
                  "Gross amount shown",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final serviceName = transaction['serviceName'] ?? 'Unknown Service';
    final customerId = transaction['customerId'] ?? '';
    final status = transaction['status'] ?? '';
    final priceStr = (transaction['totalPrice'] ?? transaction['price'] ?? '0').toString().replaceAll('RM', '').trim();
    final amount = double.tryParse(priceStr) ?? 0.0;
    
    DateTime dt = DateTime.now();
    if (transaction['completedAt'] != null) {
      dt = (transaction['completedAt'] as Timestamp).toDate();
    } else if (transaction['createdAt'] != null) {
      dt = (transaction['createdAt'] as Timestamp).toDate();
    }
    
    final dateStr = DateFormat('MMM d, yyyy').format(dt);
    final timeStr = DateFormat('h:mm a').format(dt);

    final isRefund = status == 'Cancelled';
    final color = isRefund ? Colors.red.shade600 : Colors.green.shade600;
    final icon = isRefund ? Icons.call_made : Icons.call_received;
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
