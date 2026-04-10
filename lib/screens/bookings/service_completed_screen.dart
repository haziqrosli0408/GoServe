import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rate_service_screen.dart';

class ServiceCompletedScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const ServiceCompletedScreen({super.key, required this.bookingData});

  @override
  State<ServiceCompletedScreen> createState() => _ServiceCompletedScreenState();
}

class _ServiceCompletedScreenState extends State<ServiceCompletedScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    // Circle scale animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Check mark draw animation
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    );

    // Text fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animation sequence
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _checkController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _fadeController.forward();

    // Auto-navigate to rate screen after 3 seconds total display
    await Future.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RateServiceScreen(bookingData: widget.bookingData),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated circle with check
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8C3A), Color(0xFFFF6B00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _checkAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _CheckPainter(progress: _checkAnimation.value),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title text
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_fadeAnimation),
                  child: Text(
                    'Service Completed!',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F212C),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Subtitle
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Thank you for choosing us! Your order has been successfully completed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Checkmark path points
    final startX = size.width * 0.28;
    final startY = size.height * 0.50;
    final midX = size.width * 0.44;
    final midY = size.height * 0.65;
    final endX = size.width * 0.72;
    final endY = size.height * 0.36;

    path.moveTo(startX, startY);

    if (progress <= 0.5) {
      // First stroke of check
      final t = progress / 0.5;
      path.lineTo(
        startX + (midX - startX) * t,
        startY + (midY - startY) * t,
      );
    } else {
      // First stroke complete, draw second
      path.lineTo(midX, midY);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(
        midX + (endX - midX) * t,
        midY + (endY - midY) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
