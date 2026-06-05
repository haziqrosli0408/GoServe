import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../chat/single_chat_screen.dart';
import 'upload_proof_screen.dart';
import '../../services/onesignal_service.dart';

class ActiveServiceScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const ActiveServiceScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<ActiveServiceScreen> createState() => _ActiveServiceScreenState();
}

class _ActiveServiceScreenState extends State<ActiveServiceScreen> {
  final LocationService _locationService = LocationService();
  String? customerPhone;
  String? customerName;
  String? profileUrl;

  @override
  void initState() {
    super.initState();
    _fetchCustomerDetails();
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _fetchCustomerDetails() async {
    final customerId = widget.bookingData['customerId'];
    if (customerId != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          customerName = data['name'] ?? 'Customer';
          profileUrl = data['profileUrl'];
          customerPhone = data['phone'];
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      if (newStatus == 'On the way') {
        await _locationService.startTracking(widget.bookingId);
      } else if (newStatus == 'Arrived') {
        await _locationService.stopTracking();
      }

      if (newStatus != 'Completed') {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .update({'status': newStatus});
            
        if (newStatus == 'On the way') {
          try {
            final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(widget.bookingData['providerId']).get();
            final providerName = providerDoc.data()?['name'] ?? 'Your provider';
            
            await OneSignalService.notifyProviderOnTheWay(
              customerId: widget.bookingData['customerId'],
              providerName: providerName,
              bookingId: widget.bookingId,
            );
          } catch (e) {
            debugPrint('Error sending on the way notification: $e');
          }
        }
      }
      
      if (newStatus == 'Completed') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadProofScreen(
                bookingId: widget.bookingId,
                bookingData: widget.bookingData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Confirmed';
            
            return SafeArea(
              child: Column(
                children: [
                  _buildHeader(data),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBar(status),
                          const SizedBox(height: 24),
                          _buildServiceInfo(data),
                          const SizedBox(height: 24),
                          _buildCustomerCard(),
                          const SizedBox(height: 24),
                          _buildPaymentSummary(data),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomAction(status),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
              ),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 48), // Placeholder to center the handle
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Active Service',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            data['orderId'] ?? 'GS-00000',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF1F5F9),
            backgroundImage: (profileUrl != null && profileUrl!.isNotEmpty) ? NetworkImage(profileUrl!) : null,
            child: (profileUrl == null || profileUrl!.isEmpty)
                ? Text((customerName ?? 'C')[0].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w500))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName ?? 'Loading...',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                ),
                Text(
                  customerPhone ?? 'Loading phone...',
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _iconAction(Icons.phone_outlined, () async {
                if (customerPhone != null) {
                  final cleanPhone = customerPhone!.replaceAll(RegExp(r'[^\d+]'), '');
                  final uri = Uri(scheme: 'tel', path: cleanPhone);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }
              }),
              const SizedBox(width: 8),
              _iconAction(Icons.chat_bubble_outline_rounded, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SingleChatScreen(
                      chatId: null, // Will generate
                      provider: {
                        'id': widget.bookingData['customerId'],
                        'name': customerName,
                        'profileUrl': profileUrl,
                        'serviceId': widget.bookingData['serviceId'],
                      },
                      themeColor: const Color(0xFF4F46E5), // Indigo for Provider
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
      ),
    );
  }

  Widget _buildStatusBar(String currentStatus) {
    final List<Map<String, dynamic>> stages = [
      {'label': 'On the way', 'status': 'On the way'},
      {'label': 'Arrived', 'status': 'Arrived'},
      {'label': 'In Progress', 'status': 'In progress'},
      {'label': 'Completed', 'status': 'Completed'},
    ];

    int currentIdx = stages.indexWhere((s) => s['status'] == currentStatus);
    if (currentIdx == -1 && currentStatus == 'Confirmed') currentIdx = -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Status',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        Stack(
          children: [
            // Background Line
            Positioned(
              left: 30,
              right: 30,
              top: 12,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Animated Progress Line
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: 0,
                end: currentIdx == -1 ? 0 : (currentIdx / (stages.length - 1)),
              ),
              builder: (context, value, child) {
                return Positioned(
                  left: 30,
                  right: 30,
                  top: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (index) {
                bool isCompleted = index <= currentIdx;
                bool isNext = index == currentIdx + 1;
                
                return Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: isCompleted ? 26 : 24,
                        height: isCompleted ? 26 : 24,
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFF4F46E5) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted || isNext ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                            width: isCompleted ? 0 : 2,
                          ),
                          boxShadow: isCompleted ? [
                            BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ] : [],
                        ),
                        child: isCompleted 
                          ? const Icon(Icons.check, size: 14, color: Colors.white) 
                          : (isNext ? Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle))) : null),
                      ),
                      const SizedBox(height: 8),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: index == currentIdx ? FontWeight.bold : FontWeight.normal,
                          color: index == currentIdx ? const Color(0xFF4F46E5) : (index < currentIdx ? const Color(0xFF1F293B) : Colors.grey),
                        ),
                        child: Text(stages[index]['label']),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceInfo(Map<String, dynamic> data) {
    final List<dynamic> addOns = data['selectedAddOns'] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoItem(Icons.cleaning_services_outlined, 'Service', data['serviceName'] ?? 'General Cleaning'),
        if (addOns.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add-ons', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    ...addOns.map((addon) {
                      final name = addon['name'] ?? 'Extra Service';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $name',
                          style: GoogleFonts.outfit(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600, 
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _infoItem(Icons.calendar_today_outlined, 'Date', data['date'] ?? 'No date'),
        const SizedBox(height: 16),
        _infoItem(Icons.access_time_outlined, 'Time', data['time'] ?? 'No time'),
        const SizedBox(height: 16),
        _infoItem(
          Icons.location_on_outlined, 
          'Address', 
          data['address'] ?? 'No address',
          trailing: IconButton(
            onPressed: () {
              // Get candidate data sources
              final Map<String, dynamic> combinedData = {
                ...widget.bookingData,
                ...data,
              };
              
              debugPrint("📍 Checking for coordinates in: ${combinedData.keys.toList()}");

              // Try a wide range of common coordinate field names
              double? lat;
              double? lng;

              // Potential Latitude keys
              for (var key in ['latitude', 'lat', 'targetLat', 'destLat', 'customerLat']) {
                if (combinedData[key] != null) {
                  final val = combinedData[key];
                  lat = (val is num) ? val.toDouble() : double.tryParse(val.toString());
                  if (lat != null && lat != 0) break;
                }
              }

              // Potential Longitude keys
              for (var key in ['longitude', 'lng', 'targetLng', 'destLng', 'customerLng']) {
                if (combinedData[key] != null) {
                  final val = combinedData[key];
                  lng = (val is num) ? val.toDouble() : double.tryParse(val.toString());
                  if (lng != null && lng != 0) break;
                }
              }
              
              if (lat != null && lng != null && lat != 0 && lng != 0) {
                debugPrint("🚀 Opening maps for: $lat, $lng");
                _openMaps(lat, lng);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Coordinates not found in: ${combinedData.keys.where((k) => k.contains('lat') || k.contains('lng')).join(', ')}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.near_me_rounded, color: Color(0xFF4F46E5), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPaymentSummary(Map<String, dynamic> data) {
    final totalPrice = double.tryParse(data['totalPrice']?.toString().replaceAll('RM', '').trim() ?? '0') ?? 0.0;
    
    // Use stored chargeFee if available, or calculate from 15% markup (Total = Subtotal * 1.15)
    double platformFee = 0.0;
    if (data['chargeFee'] != null) {
      platformFee = (data['chargeFee'] as num).toDouble();
    } else {
      // Fallback: Fee = Total - (Total / 1.15)
      platformFee = totalPrice - (totalPrice / 1.15);
    }
    
    final netEarnings = totalPrice - platformFee;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _priceRow('Total Price', 'RM ${totalPrice.toStringAsFixed(2)}', const Color(0xFF64748B), valueColor: const Color(0xFF1E293B)),
          const SizedBox(height: 8),
          _priceRow('Platform Fee (15%)', '- RM ${platformFee.toStringAsFixed(2)}', const Color(0xFF64748B), valueColor: Colors.red.shade500),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey.shade200),
          ),
          _priceRow('Your Earnings', 'RM ${netEarnings.toStringAsFixed(2)}', const Color(0xFF1E293B), valueColor: const Color(0xFF4F46E5), isBold: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color labelColor, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: labelColor, fontSize: 14)),
        Text(value, style: GoogleFonts.outfit(color: valueColor ?? labelColor, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildBottomAction(String status) {
    String btnText = 'Update Status';
    Color btnColor = const Color(0xFF4F46E5);
    VoidCallback? action;

    if (status == 'Confirmed') {
      btnText = 'On the way';
      action = () => _updateStatus('On the way');
    } else if (status == 'On the way') {
      btnText = "I've Arrived";
      action = () => _updateStatus('Arrived');
    } else if (status == 'Arrived') {
      btnText = 'Start Service';
      action = () => _updateStatus('In progress');
    } else if (status == 'In progress') {
      btnText = 'Complete Service';
      action = () => _updateStatus('Completed');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: action,
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(btnText, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
