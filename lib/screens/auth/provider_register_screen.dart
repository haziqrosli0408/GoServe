import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:gooservee/services/google_auth_service.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:gooservee/utils/categories_data.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});

  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirm = true;
  bool isGettingLocation = false;
  int _strength = 0;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool showBankList = false;
  bool isGoogleUser = false;
  double? _latitude;
  double? _longitude;

  Future<void> _googleSignUp() async {
    setState(() => isLoading = true);
    try {
      final userCredential = await _googleAuthService.signInWithGoogle();
      if (userCredential == null) {
        setState(() => isLoading = false);
        return;
      }

      final user = userCredential.user!;
      
      setState(() {
        isGoogleUser = true;
        emailController.text = user.email ?? "";
        if (nameController.text.isEmpty) {
          nameController.text = user.displayName ?? "";
        }
        // Advance to next step (Location)
        _currentStep++;
      });
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google account linked! Please complete the remaining steps.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final addressController = TextEditingController();
  final accountNumberController = TextEditingController();
  
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

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _strength = _calculateStrength(passwordController.text);
    });
  }

  int _calculateStrength(String password) {
    if (password.isEmpty) return 0;

    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSymbol = password.contains(RegExp(r'[@#$!%^&*(),.?":{}|<>]'));

    if (hasLowercase && hasUppercase && hasNumber && hasSymbol) return 4;
    if (hasLowercase && hasUppercase && hasNumber) return 3;
    if (hasLowercase && hasUppercase) return 2;
    if (hasLowercase) return 1;
    return 0;
  }
  
  List<String> selectedServices = [];

  List<Map<String, dynamic>> get services => AppCategories.getHomeCategories();

  void _nextStep() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      if (_currentStep < 5) {
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _signUp();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFile = pickedFile;
      });
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageBytes == null) return null;

    try {
      final fileName = path.basename(_imageFile!.path);
      final destination = 'provider_profile_photos/$uid/$fileName';
      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putData(_imageBytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      // Error uploading image
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      String? address;

      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            address = "${place.street != null && place.street!.isNotEmpty ? '${place.street}, ' : ''}${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}";
            address = address.replaceAll(RegExp(r'^, |, $'), '');
          }
        } catch (e) {
          debugPrint("Geocoding failed: $e");
        }
      } else {
        // Web Geocoding Fallback using Google Maps API
        try {
          // Use the API key found in web/index.html
          const apiKey = "AIzaSyAbuq1D2c5ZgL5jGjQSCp3tFWx2S7aBl60";
          final url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey";
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'].isNotEmpty) {
              address = data['results'][0]['formatted_address'];
            }
          }
        } catch (e) {
          debugPrint("Web Geocoding failed: $e");
        }
      }
      
      if (address != null && address.isNotEmpty) {
        addressController.text = address;
      } else {
        addressController.text = "${position.latitude}, ${position.longitude}";
      }
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => isGettingLocation = false);
      }
    }
  }

  Future<void> _signUp() async {
    setState(() => isLoading = true);

    try {
      String uid;
      
      if (isGoogleUser) {
        // Already signed in via Google
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User not found");
        uid = user.uid;
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        uid = userCredential.user!.uid;
      }

      // 🔥 Upload profile photo if exists
      if (_imageBytes != null) {
        _profileImageUrl = await _uploadImage(uid);
      }

      // Generate Sequential USRXXX ID by querying last user
      String customId = "USR000";
      try {
        final lastUserQuery = await FirebaseFirestore.instance
            .collection("users")
            .orderBy("customId", descending: true)
            .limit(1)
            .get();
        
        final lastProviderQuery = await FirebaseFirestore.instance
            .collection("providers")
            .orderBy("customId", descending: true)
            .limit(1)
            .get();

        int maxNum = -1;
        
        if (lastUserQuery.docs.isNotEmpty) {
          final id = lastUserQuery.docs.first.data()['customId'] as String?;
          if (id != null && id.startsWith("USR")) {
            maxNum = max(maxNum, int.tryParse(id.replaceFirst("USR", "")) ?? -1);
          }
        }

        if (lastProviderQuery.docs.isNotEmpty) {
          final id = lastProviderQuery.docs.first.data()['customId'] as String?;
          if (id != null && id.startsWith("USR")) {
            maxNum = max(maxNum, int.tryParse(id.replaceFirst("USR", "")) ?? -1);
          }
        }

        customId = 'USR${(maxNum + 1).toString().padLeft(3, '0')}';
      } catch (e) {
        debugPrint("ID Generation Error: $e");
        // Fallback to timestamp if query fails
        customId = 'USR${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';
      }

      // 🔥 Save provider data to Firestore
      await FirebaseFirestore.instance.collection("providers").doc(uid).set({
        "uid": uid,
        "customId": customId, // 👈 New field
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
        "address": addressController.text.trim(),
        "profileUrl": _profileImageUrl ?? "",
        "bankName": selectedBank,
        "accountNumber": accountNumberController.text.trim(),
        "services": selectedServices,
        "role": "provider",
        "status": "Active",
        "latitude": _latitude,
        "longitude": _longitude,
        "createdAt": DateTime.now(),
      });

      if (!mounted) return;

      if (mounted) {
        Navigator.pushReplacementNamed(context, "/provider");
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Registration failed";
      if (e.code == "email-already-in-use") {
        errorMsg = "This email is already used";
      } else if (e.code == "weak-password") {
        errorMsg = "Password is too weak";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    addressController.dispose();
    accountNumberController.dispose();
    super.dispose();
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(6, (index) {
        bool isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Color(0xFF4F46E5) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D3748), size: 20),
          onPressed: () {
            if (_currentStep == 0) {
              Navigator.pop(context);
            } else {
              _prevStep();
            }
          },
        ),
        title: const Text(
          "Sign Up",
          style: TextStyle(color: Color(0xFF2B3748), fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _buildStepIndicator(),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepIdentity(),
                _buildStepProfilePhoto(),
                _buildStepSecurity(),
                _buildStepLocation(),
                _buildStepPayment(),
                _buildStepServices(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (isLoading || (_currentStep == 1 && _imageBytes == null)) ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_currentStep == 1 && _imageBytes == null)
                              ? Colors.grey.shade400
                              : const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentStep == 0
                                        ? "Next"
                                        : (_currentStep == 1
                                            ? "Continue"
                                            : (_currentStep == 5 ? "Complete" : "Continue")),
                                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_currentStep == 1) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _nextStep,
                        child: const Text("Skip for now", style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w400, fontSize: 13)),
                      )
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Color(0xFF2D3748), height: 1.1),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Build Your\nPro Profile", "Enter your professional identity to begin\nproviding services."),
            _inputField(
              controller: nameController,
              label: "PROFESSIONAL NAME",
              hint: "Enter your full name or business name",
              icon: Icons.person,
              validator: (v) => v!.isEmpty ? "Professional name is required" : null,
            ),
            const SizedBox(height: 20),
            const Text("Phone number", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text("+60", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Phone number required";
                      if (v.length < 9 || v.length > 11) return "Enter a valid phone number (9-11 digits)";
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: "123456789",
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProfilePhoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const Text(
                  "Set Your Profile\nPhoto",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF2D3748), height: 1.1),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Clients prefer seeing who they are\nhiring. Build trust with a photo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 48),
              ],
            ),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        image: _imageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_imageBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Center(
                              child: Icon(Icons.person, size: 80, color: Color(0xFFCBD5E1)),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Icon(
                          _imageFile == null ? Icons.camera_alt : Icons.edit,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF1F8F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "You can always change your photo later in\nyour profile settings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSecurity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Secure Your Account", "Use a valid email and a strong password."),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoading ? null : _googleSignUp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      "https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png",
                      height: 18,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, size: 20, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Continue with Google",
                      style: TextStyle(fontSize: 14, color: Color(0xFF2D3748), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("or", style: TextStyle(color: Colors.black26, fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 24),

            _inputField(
              controller: emailController,
              label: "EMAIL ADDRESS",
              hint: "user@goserve.com",
              suffixIcon: const Icon(Icons.check_circle, color: Color(0xFF000000), size: 18),
              validator: (v) {
                if (v!.isEmpty) return "Email is required";
                if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$").hasMatch(v)) return "Invalid email";
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text("Password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordController,
              obscureText: hidePassword,
              validator: (v) {
                if (v!.isEmpty) return "Password required";
                if (v.length < 8) return "Minimum 8 characters";
                bool hasLowercase = v.contains(RegExp(r'[a-z]'));
                bool hasUppercase = v.contains(RegExp(r'[A-Z]'));
                bool hasNumber = v.contains(RegExp(r'[0-9]'));
                bool hasSymbol = v.contains(RegExp(r'[@#$!%^&*(),.?":{}|<>]'));
                
                if (!hasLowercase || !hasUppercase || !hasNumber || !hasSymbol) {
                  return "Must include Upper, Lower, Number & Symbol";
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: "••••••••••••",
                suffixIcon: IconButton(
                  icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility, color: Colors.black54, size: 20),
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Password strength", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
                const Spacer(),
                Text(
                  _strength == 0
                      ? ""
                      : (_strength == 1
                          ? "Weak"
                          : (_strength == 2
                              ? "Fair"
                              : (_strength == 3 ? "Strong" : "Very Strong"))),
                  style: TextStyle(
                    color: _strength == 1 
                        ? Colors.red 
                        : (_strength == 2 
                            ? Colors.orange 
                            : (_strength == 3 ? Colors.yellow.shade700 : (_strength == 4 ? Colors.green : Colors.grey))),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (index) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index < _strength
                          ? (_strength == 1
                              ? Colors.red
                              : (_strength == 2 
                                  ? Colors.orange 
                                  : (_strength == 3 ? Colors.yellow : Colors.green)))
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text("Confirm password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextFormField(
              controller: confirmController,
              obscureText: hideConfirm,
              validator: (v) {
                if (v != passwordController.text) return "Passwords do not match";
                return null;
              },
              decoration: InputDecoration(
                hintText: "••••••••••••",
                suffixIcon: IconButton(
                  icon: Icon(hideConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.black54, size: 20),
                  onPressed: () => setState(() => hideConfirm = !hideConfirm),
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLocation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Service Area", "Where do you provide your services?"),
            
            InkWell(
              onTap: isGettingLocation ? null : _getCurrentLocation,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isGettingLocation)
                      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    else ...[
                      const Icon(Icons.my_location, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text("Detect my area", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _inputField(
              controller: addressController,
              label: "BUSINESS ADDRESS",
              hint: "Search for your location...",
              icon: Icons.location_on,
              validator: (v) => v!.isEmpty ? "Address is required" : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPayment() {
    final selectedBankDomain = selectedBank != null ? bankDomains[selectedBank!] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Get Paid\nDirectly", "Securely add your payment details to receive\nearnings directly."),
            
            const Text("Bank account", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
            const SizedBox(height: 12),

            // --- Custom Premium Dropdown ---
            GestureDetector(
              onTap: () => setState(() => showBankList = !showBankList),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: showBankList ? const BorderRadius.vertical(top: Radius.circular(8)) : BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    if (selectedBank != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          "https://www.google.com/s2/favicons?sz=64&domain=$selectedBankDomain",
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 18, color: Colors.black26),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else
                      const Icon(Icons.account_balance, color: Colors.black54, size: 20),
                    
                    if (selectedBank == null) const SizedBox(width: 12),
                    
                    Expanded(
                      child: Text(
                        selectedBank ?? "Choose your bank account",
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedBank != null ? const Color(0xFF1E293B) : Colors.black38,
                          fontWeight: selectedBank != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      showBankList ? Icons.expand_less : Icons.expand_more,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),

            if (showBankList)
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: banks.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final bank = banks[index];
                    final domain = bankDomains[bank];
                    final isSelected = selectedBank == bank;
                    
                    return ListTile(
                      onTap: () {
                        setState(() {
                          selectedBank = bank;
                          showBankList = false;
                        });
                      },
                      leading: Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Image.network(
                          "https://www.google.com/s2/favicons?sz=64&domain=$domain",
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, size: 16, color: Colors.black26),
                        ),
                      ),
                      title: Text(
                        bank,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF2D3748),
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 18) : null,
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 24),
            _inputField(
              controller: accountNumberController,
              label: "ACCOUNT NUMBER",
              hint: "Enter your bank account number",
              icon: Icons.credit_card,
              keyboard: TextInputType.number,
              validator: (v) => v!.isEmpty ? "Account number is required" : null,
            ),
            const SizedBox(height: 80), // Added spacing to avoid overlap
          ],
        ),
      ),
    );
  }

  Widget _buildStepServices() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKeys[5],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Your Services", "What services do you offer? Clients will search\nfor you based on these."),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final service = services[index];
                final isSelected = selectedServices.contains(service['name']);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedServices.remove(service['name']);
                      } else {
                        selectedServices.add(service['name']);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE0E7FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(service['icon'], color: const Color(0xFF000000), size: 20),
                        const SizedBox(height: 8),
                        Text(
                          service['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isSelected ? const Color(0xFF000000) : const Color(0xFF2D3748)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    TextInputType keyboard = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.substring(0, 1).toUpperCase() + label.substring(1).toLowerCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
            prefixIcon: icon != null ? Icon(icon, color: Colors.black54, size: 20) : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
