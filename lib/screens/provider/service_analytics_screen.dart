import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_service_screen.dart';

class ServiceAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;

  const ServiceAnalyticsScreen({super.key, required this.serviceData});

  @override
  State<ServiceAnalyticsScreen> createState() => _ServiceAnalyticsScreenState();
}

class _ServiceAnalyticsScreenState extends State<ServiceAnalyticsScreen> {
  bool _isLoading = true;
  String _timeframe = 'All Time'; // 'All Time' or 'Last 30 Days'
  
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  List<Map<String, dynamic>> _reviews = [];

  // Metrics
  int _totalBookingsCount = 0;
  int _completedCount = 0;
  int _cancelledCount = 0;
  int _inProgressCount = 0;
  double _completionRate = 0.0;
  double _totalRevenue = 0.0;
  double _receivedRevenue = 0.0;
  double _escrowRevenue = 0.0;
  double _avgRating = 0.0;
  
  // Distribution
  Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  int _repeatCustomersCount = 0;
  int _uniqueCustomersCount = 0;
  String _peakDay = 'N/A';
  double _avgBookingValue = 0.0;
  
  // Monthly chart data (Last 6 Months)
  List<Map<String, dynamic>> _monthlyChartData = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  String get _serviceId => widget.serviceData['id'] ?? widget.serviceData['serviceId'] ?? '';

  Future<void> _fetchAnalyticsData() async {
    if (_serviceId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch Bookings for this service
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('serviceId', isEqualTo: _serviceId)
          .get();

      // 2. Fetch Reviews for this service
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('serviceId', isEqualTo: _serviceId)
          .get();

      _allBookings = bookingsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _reviews = reviewsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _processData();
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processData() {
    // Filter bookings based on timeframe
    final now = DateTime.now();
    if (_timeframe == 'Last 30 Days') {
      _filteredBookings = _allBookings.where((b) {
        DateTime dt = now;
        if (b['createdAt'] != null) {
          dt = (b['createdAt'] as Timestamp).toDate();
        } else if (b['completedAt'] != null) {
          dt = (b['completedAt'] as Timestamp).toDate();
        }
        return now.difference(dt).inDays <= 30;
      }).toList();
    } else {
      _filteredBookings = List.from(_allBookings);
    }

    // Calculations
    _totalBookingsCount = _filteredBookings.length;
    _completedCount = _filteredBookings.where((b) => b['status'] == 'Completed').length;
    _cancelledCount = _filteredBookings.where((b) => b['status'] == 'Cancelled').length;
    _inProgressCount = _totalBookingsCount - _completedCount - _cancelledCount;

    // Completion Rate
    final finishedOrCancelled = _completedCount + _cancelledCount;
    if (finishedOrCancelled > 0) {
      _completionRate = (_completedCount / finishedOrCancelled) * 100;
    } else {
      _completionRate = 0.0;
    }

    // Revenue
    _totalRevenue = 0.0;
    _receivedRevenue = 0.0;
    _escrowRevenue = 0.0;
    for (var b in _filteredBookings.where((b) => b['status'] == 'Completed')) {
      final priceStr = (b['totalPrice'] ?? b['price'] ?? '0').toString().replaceAll('RM', '').trim();
      final totalPrice = double.tryParse(priceStr) ?? 0.0;
      double chargeFee = 0.0;
      if (b['chargeFee'] != null) {
        chargeFee = (b['chargeFee'] as num).toDouble();
      } else {
        chargeFee = totalPrice - (totalPrice / 1.15);
      }
      final netPayout = totalPrice - chargeFee;
      _totalRevenue += netPayout;

      if (b['payoutStatus'] == 'transferred') {
        _receivedRevenue += netPayout;
      } else {
        _escrowRevenue += netPayout;
      }
    }

    // Average Booking Value
    if (_completedCount > 0) {
      _avgBookingValue = _totalRevenue / _completedCount;
    } else {
      _avgBookingValue = 0.0;
    }

    // Average Rating & Rating distribution
    _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    double sumRating = 0.0;
    int ratingCount = 0;
    for (var r in _reviews) {
      final ratingVal = r['rating'];
      if (ratingVal is num) {
        final ratingInt = ratingVal.round();
        if (ratingInt >= 1 && ratingInt <= 5) {
          _ratingDistribution[ratingInt] = (_ratingDistribution[ratingInt] ?? 0) + 1;
        }
        sumRating += ratingVal.toDouble();
        ratingCount++;
      }
    }
    _avgRating = ratingCount > 0 ? sumRating / ratingCount : 0.0;

    // Customer Insights
    final customerCounts = <String, int>{};
    for (var b in _filteredBookings) {
      final customerId = b['customerId'] ?? '';
      if (customerId.isNotEmpty) {
        customerCounts[customerId] = (customerCounts[customerId] ?? 0) + 1;
      }
    }
    _uniqueCustomersCount = customerCounts.keys.length;
    _repeatCustomersCount = customerCounts.values.where((c) => c > 1).length;

    // Peak Day of the Week
    final dayCounts = <int, int>{};
    for (var b in _filteredBookings) {
      DateTime dt = DateTime.now();
      if (b['createdAt'] != null) {
        dt = (b['createdAt'] as Timestamp).toDate();
      } else if (b['completedAt'] != null) {
        dt = (b['completedAt'] as Timestamp).toDate();
      }
      dayCounts[dt.weekday] = (dayCounts[dt.weekday] ?? 0) + 1;
    }
    if (dayCounts.isNotEmpty) {
      final sortedDays = dayCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final peakWeekday = sortedDays.first.key;
      _peakDay = _getWeekdayName(peakWeekday);
    } else {
      _peakDay = 'N/A';
    }

    // Monthly Chart Data (Last 6 Months)
    _monthlyChartData = [];
    final monthFormat = DateFormat('MMM');
    for (int i = 5; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);
      final monthLabel = monthFormat.format(monthStart);

      final monthBookings = _allBookings.where((b) {
        DateTime dt = now;
        if (b['createdAt'] != null) {
          dt = (b['createdAt'] as Timestamp).toDate();
        } else if (b['completedAt'] != null) {
          dt = (b['completedAt'] as Timestamp).toDate();
        }
        return dt.isAfter(monthStart) && dt.isBefore(monthEnd);
      }).toList();

      _monthlyChartData.add({
        'label': monthLabel,
        'count': monthBookings.length,
      });
    }
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeIndigo = const Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Service Analytics',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: themeIndigo),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditServiceScreen(serviceData: widget.serviceData),
                ),
              ).then((_) => _fetchAnalyticsData());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeIndigo))
          : RefreshIndicator(
              onRefresh: _fetchAnalyticsData,
              color: themeIndigo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header service description
                    _buildServiceHeader(themeIndigo),
                    const SizedBox(height: 24),

                    // Timeframe Selector
                    _buildTimeframeSelector(themeIndigo),
                    const SizedBox(height: 20),

                    // KPI Cards Grid
                    _buildKpiGrid(themeIndigo),
                    const SizedBox(height: 24),

                    // Monthly Trend Chart
                    _buildMonthlyTrendChart(themeIndigo),
                    const SizedBox(height: 24),

                    // Booking Status Breakdown
                    _buildStatusBreakdownCard(),
                    const SizedBox(height: 24),

                    // Rating Distribution
                    _buildRatingDistributionCard(),
                    const SizedBox(height: 24),

                    // Customer Insights & Booking insights
                    _buildInsightsCard(themeIndigo),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildServiceHeader(Color themeColor) {
    final String? imageUrl = widget.serviceData['servicePhotoUrl'];
    final String title = widget.serviceData['title'] ?? 'Untitled Service';
    final String category = widget.serviceData['category'] ?? '';
    final String subCategory = category.contains('>')
        ? category.split('>').last.trim()
        : category;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: const Color(0xFFF1F5F9),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Icon(Icons.home_repair_service_rounded, color: themeColor.withValues(alpha: 0.4), size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subCategory,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade500,
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

  Widget _buildTimeframeSelector(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['All Time', 'Last 30 Days'].map((tf) {
          final isSelected = _timeframe == tf;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _timeframe = tf;
                  _isLoading = true;
                });
                _processData();
                setState(() => _isLoading = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tf,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? themeColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiGrid(Color themeColor) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.45,
      children: [
        _buildKpiCard(
          'Total Bookings',
          '$_totalBookingsCount',
          Icons.calendar_month_rounded,
          const Color(0xFF3B82F6),
        ),
        _buildKpiCard(
          'Avg Rating',
          _avgRating > 0 ? _avgRating.toStringAsFixed(1) : 'New',
          Icons.star_rounded,
          const Color(0xFFF59E0B),
          suffix: _reviews.isNotEmpty ? ' (${_reviews.length} reviews)' : '',
        ),
        _buildKpiCard(
          'Completed Rate',
          '${_completionRate.toStringAsFixed(0)}%',
          Icons.task_alt_rounded,
          const Color(0xFF10B981),
        ),
        _buildKpiCard(
          'Revenue (Net)',
          'RM ${_totalRevenue.toStringAsFixed(0)}',
          Icons.payments_rounded,
          const Color(0xFF4F46E5),
          subText: 'Received: RM ${_receivedRevenue.toStringAsFixed(0)} • Escrow: RM ${_escrowRevenue.toStringAsFixed(0)}',
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {String suffix = '', String subText = ''}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (subText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subText,
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(Color themeColor) {
    // Find max value for scaling
    int maxCount = 1;
    for (var m in _monthlyChartData) {
      if (m['count'] > maxCount) {
        maxCount = m['count'];
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bookings Trend',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Number of bookings over the last 6 months',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyChartData.map((data) {
                final count = data['count'] as int;
                final label = data['label'] as String;
                final percentage = count / maxCount;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: count > 0 ? themeColor : Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 24,
                        height: (100 * percentage).clamp(6.0, 100.0),
                        decoration: BoxDecoration(
                          color: count > 0 ? themeColor : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdownCard() {
    final double completedPct = _totalBookingsCount > 0 ? (_completedCount / _totalBookingsCount) : 0.0;
    final double cancelledPct = _totalBookingsCount > 0 ? (_cancelledCount / _totalBookingsCount) : 0.0;
    final double activePct = _totalBookingsCount > 0 ? (_inProgressCount / _totalBookingsCount) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Status Breakdown',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 18),
          // Single segmented bar chart
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (_completedCount > 0)
                    Expanded(
                      flex: (_completedCount * 100).round(),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (_inProgressCount > 0)
                    Expanded(
                      flex: (_inProgressCount * 100).round(),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (_cancelledCount > 0)
                    Expanded(
                      flex: (_cancelledCount * 100).round(),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (_totalBookingsCount == 0)
                    Expanded(
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusIndicator('Completed', '$_completedCount', const Color(0xFF10B981), completedPct),
              _buildStatusIndicator('In Progress', '$_inProgressCount', const Color(0xFF3B82F6), activePct),
              _buildStatusIndicator('Cancelled', '$_cancelledCount', const Color(0xFFEF4444), cancelledPct),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String count, Color color, double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count (${(pct * 100).toStringAsFixed(0)}%)',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistributionCard() {
    int maxReviews = 1;
    for (var count in _ratingDistribution.values) {
      if (count > maxReviews) {
        maxReviews = count;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Distribution',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...[5, 4, 3, 2, 1].map((stars) {
            final count = _ratingDistribution[stars] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$stars★',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: _reviews.isNotEmpty ? count / _reviews.length : 0.0,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      textAlign: Alignment.centerRight.x > 0 ? TextAlign.right : TextAlign.left,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Insights',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            'Peak Booking Day',
            _peakDay,
            Icons.trending_up_rounded,
            themeColor,
          ),
          Divider(height: 24, thickness: 0.5, color: Colors.grey.shade200),
          _buildInsightItem(
            'Average Booking Value',
            'RM ${_avgBookingValue.toStringAsFixed(2)}',
            Icons.monetization_on_rounded,
            const Color(0xFF10B981),
          ),
          Divider(height: 24, thickness: 0.5, color: Colors.grey.shade200),
          _buildInsightItem(
            'Unique Customers',
            '$_uniqueCustomersCount customer${_uniqueCustomersCount == 1 ? '' : 's'}',
            Icons.people_alt_rounded,
            const Color(0xFF3B82F6),
          ),
          if (_uniqueCustomersCount > 0) ...[
            Divider(height: 24, thickness: 0.5, color: Colors.grey.shade200),
            _buildInsightItem(
              'Repeat Customer Rate',
              '${((_repeatCustomersCount / _uniqueCustomersCount) * 100).toStringAsFixed(0)}% ($_repeatCustomersCount repeat)',
              Icons.loop_rounded,
              const Color(0xFF8B5CF6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
