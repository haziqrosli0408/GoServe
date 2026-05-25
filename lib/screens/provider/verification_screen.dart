import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  int step = 1;
  dynamic _selfie; // File or XFile
  dynamic _icFront; // File or XFile
  dynamic _icBack; // File or XFile
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(int targetStep) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: targetStep == 1 ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 50,
    );

    if (image != null) {
      setState(() {
        if (targetStep == 1) {
          _selfie = kIsWeb ? image : File(image.path);
        } else if (targetStep == 2) {
          _icFront = kIsWeb ? image : File(image.path);
        } else {
          _icBack = kIsWeb ? image : File(image.path);
        }
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_selfie == null || _icFront == null || _icBack == null) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Upload Selfie
      final selfieRef = FirebaseStorage.instance
          .ref()
          .child('verification/${user.uid}/selfie.jpg');
      if (kIsWeb) {
        await selfieRef.putData(await (_selfie as XFile).readAsBytes());
      } else {
        await selfieRef.putFile(_selfie as File);
      }
      final selfieUrl = await selfieRef.getDownloadURL();

      // 2. Upload IC Front
      final icFrontRef = FirebaseStorage.instance
          .ref()
          .child('verification/${user.uid}/ic_front.jpg');
      if (kIsWeb) {
        await icFrontRef.putData(await (_icFront as XFile).readAsBytes());
      } else {
        await icFrontRef.putFile(_icFront as File);
      }
      final icFrontUrl = await icFrontRef.getDownloadURL();

      // 3. Upload IC Back
      final icBackRef = FirebaseStorage.instance
          .ref()
          .child('verification/${user.uid}/ic_back.jpg');
      if (kIsWeb) {
        await icBackRef.putData(await (_icBack as XFile).readAsBytes());
      } else {
        await icBackRef.putFile(_icBack as File);
      }
      final icBackUrl = await icBackRef.getDownloadURL();

      // 4. Update Firestore
      await FirebaseFirestore.instance.collection('providers').doc(user.uid).update({
        'verificationStatus': 'pending',
        'selfieUrl': selfieUrl,
        'icFrontUrl': icFrontUrl,
        'icBackUrl': icBackUrl,
        'verificationRequestDate': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success popup and pop
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
              const SizedBox(height: 20),
              Text(
                'Submission Sent!',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account will be approved in 1-2 working days.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Close screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Dashboard'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Account Verification', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 40),
            Expanded(
              child: step == 1 
                ? _buildSelfieStep() 
                : step == 2 
                  ? _buildICFrontStep() 
                  : _buildICBackStep()
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepCircle(1, 'Selfie', step >= 1),
        Expanded(child: Container(height: 2, color: step >= 2 ? const Color(0xFF4F46E5) : Colors.grey[200])),
        _stepCircle(2, 'IC Front', step >= 2),
        Expanded(child: Container(height: 2, color: step >= 3 ? const Color(0xFF4F46E5) : Colors.grey[200])),
        _stepCircle(3, 'IC Back', step >= 3),
      ],
    );
  }

  Widget _stepCircle(int n, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4F46E5) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: active ? const Color(0xFF4F46E5) : Colors.grey[300]!),
          ),
          child: Center(
            child: Text(
              n.toString(),
              style: GoogleFonts.outfit(
                color: active ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: active ? Colors.black : Colors.grey[400])),
      ],
    );
  }

  Widget _buildSelfieStep() {
    return Column(
      children: [
        Text(
          'Take a Selfie',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Make sure your face is clearly visible and well-lit.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.grey[600]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _pickImage(1),
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2), width: 2),
              image: _selfie != null 
                ? DecorationImage(
                    image: kIsWeb ? NetworkImage((_selfie as XFile).path) : FileImage(_selfie as File) as ImageProvider, 
                    fit: BoxFit.cover
                  ) 
                : null,
            ),
            child: _selfie == null
                ? Icon(Icons.face_rounded, size: 80, color: Colors.grey[300])
                : null,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildICFrontStep() {
    return Column(
      children: [
        Text(
          'IC: Front Side',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Please take a clear photo of the front of your IC.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.grey[600]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _pickImage(2),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2), width: 2),
              image: _icFront != null 
                ? DecorationImage(
                    image: kIsWeb ? NetworkImage((_icFront as XFile).path) : FileImage(_icFront as File) as ImageProvider, 
                    fit: BoxFit.cover
                  ) 
                : null,
            ),
            child: _icFront == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('Capture Front Photo', style: GoogleFonts.outfit(color: Colors.grey[400])),
                    ],
                  )
                : null,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildICBackStep() {
    return Column(
      children: [
        Text(
          'IC: Back Side',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          'Please take a clear photo of the back of your IC.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.grey[600]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _pickImage(3),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2), width: 2),
              image: _icBack != null 
                ? DecorationImage(
                    image: kIsWeb ? NetworkImage((_icBack as XFile).path) : FileImage(_icBack as File) as ImageProvider, 
                    fit: BoxFit.cover
                  ) 
                : null,
            ),
            child: _icBack == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('Capture Back Photo', style: GoogleFonts.outfit(color: Colors.grey[400])),
                    ],
                  )
                : null,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildFooter() {
    bool canProceed = (step == 1 && _selfie != null) || (step == 2 && _icFront != null) || (step == 3 && _icBack != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: !canProceed || _isUploading
                ? null
                : () {
                    if (step < 3) {
                      setState(() => step++);
                    } else {
                      _submitVerification();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    step == 1 ? 'Next Step' : 'Submit Verification',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
        if (step > 1)
          TextButton(
            onPressed: () => setState(() => step--),
            child: Text('Back to Step ${step - 1}', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
      ],
    );
  }
}
