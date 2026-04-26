import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:geocoding/geocoding.dart';
import '../../utils/categories_data.dart';

class AddServiceScreen extends StatefulWidget {
  final bool startNew;
  final Map<String, dynamic>? initialDraftData;
  const AddServiceScreen({super.key, this.startNew = false, this.initialDraftData});

  static Stream<List<Map<String, dynamic>>> getDraftsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    
    return FirebaseFirestore.instance
        .collection('providers')
        .doc(user.uid)
        .collection('serviceDrafts')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return _convertToRuntimeMap(data);
          }).toList();
        });
  }

  static Map<String, dynamic> _convertToRuntimeMap(Map<String, dynamic> firestoreData) {
    final Map<String, dynamic> runtimeData = Map.from(firestoreData);
    if (firestoreData['mainImagePath'] != null) {
      runtimeData['mainImage'] = File(firestoreData['mainImagePath']);
    }
    if (firestoreData['galleryImagePaths'] != null) {
      runtimeData['galleryImages'] = (firestoreData['galleryImagePaths'] as List).map((path) => File(path)).toList();
    }
    return runtimeData;
  }
  
  static Future<void> clearDraft(String draftId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .collection('serviceDrafts')
          .doc(draftId)
          .delete();
    }
  }

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  int step = 1;
  static const int totalSteps = 5;
  String? selectedCategory;
  String? draftId;
  
  // States
  File? _mainImage;
  final List<File> _galleryImages = [];
  String? _networkMainImage; // For already uploaded images
  final List<String> _networkGalleryImages = []; // For already uploaded images
  final List<String> _serviceDetails = [];
  final List<Map<String, dynamic>> _addOns = [];
  
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addOnNameController = TextEditingController();
  final TextEditingController _addOnPriceController = TextEditingController();
  final TextEditingController _addOnDescriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _priceType = 'per hour'; // 'per hour' or 'one-time'
  
  List<Map<String, dynamic>> get _categoryData {
    return AppCategories.allCategories.map((cat) {
      final name = cat['name'] as String;
      final subcats = AppCategories.subcategoryMap[name] ?? [];
      return {
        'name': name,
        'icon': cat['icon'],
        'subs': subcats.map((s) => s['name'] as String).toList(),
      };
    }).toList();
  }

  final ImagePicker _picker = ImagePicker();
  final Color primaryIndigo = const Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    // Load from draft data if provided
    if (!widget.startNew && widget.initialDraftData != null) {
      final draft = widget.initialDraftData!;
      draftId = draft['id'];
      step = draft['step'] ?? 1;
      _titleController.text = draft['title'] ?? '';
      selectedCategory = draft['category'];
      _descriptionController.text = draft['description'] ?? '';
      _priceController.text = draft['price'] ?? '';
      _priceType = draft['priceType'] ?? 'per hour';
      _mainImage = draft['mainImage'];
      
      if (widget.initialDraftData!['galleryUrls'] != null) {
        _networkGalleryImages.clear();
        _networkGalleryImages.addAll(List<String>.from(widget.initialDraftData!['galleryUrls']));
      } else if (widget.initialDraftData!['galleryImagePaths'] != null) {
        _galleryImages.addAll(List<File>.from(draft['galleryImages']));
      }
      if (draft['details'] != null) {
        _serviceDetails.addAll(List<String>.from(draft['details']));
      }
      if (draft['addOns'] != null) {
        _addOns.addAll(List<Map<String, dynamic>>.from(draft['addOns']));
      }
    }
  }

  Future<void> _saveDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (selectedCategory == null && _titleController.text.isEmpty && step == 1) {
      return; 
    }

    final Map<String, dynamic> currentData = {
      'step': step,
      'title': _titleController.text,
      'category': selectedCategory,
      'description': _descriptionController.text,
      'price': _priceController.text,
      'priceType': _priceType,
      'mainImagePath': _mainImage?.path,
      'details': _serviceDetails,
      'galleryImagePaths': _galleryImages.map((e) => e.path).toList(),
      'addOns': _addOns,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final collection = FirebaseFirestore.instance
        .collection('providers')
        .doc(user.uid)
        .collection('serviceDrafts');

    if (draftId != null) {
      await collection.doc(draftId).update(currentData);
    } else {
      await collection.add(currentData);
    }
  }

  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      setState(() => _mainImage = File(image.path));
    }
  }

  Future<void> _pickGalleryImages() async {
    if (_galleryImages.length >= 6) return;
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (images.isNotEmpty) {
      setState(() {
        for (var image in images) {
          if (_galleryImages.length < 6) {
            _galleryImages.add(File(image.path));
          }
        }
      });
    }
  }

  void _addDetail() {
    if (_detailController.text.trim().isNotEmpty) {
      setState(() {
        _serviceDetails.add(_detailController.text.trim());
        _detailController.clear();
      });
    }
  }

  void _addAddOn() {
    if (_addOnNameController.text.trim().isNotEmpty && 
        _addOnPriceController.text.trim().isNotEmpty &&
        _addOnDescriptionController.text.trim().isNotEmpty) {
      setState(() {
        _addOns.add({
          'name': _addOnNameController.text.trim(),
          'price': _addOnPriceController.text.trim(),
          'description': _addOnDescriptionController.text.trim(),
        });
        _addOnNameController.clear();
        _addOnPriceController.clear();
        _addOnDescriptionController.clear();
      });
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _addOnNameController.dispose();
    _addOnPriceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderNav(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StepIndicatorDelegate(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildStepIndicator(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: _buildStepContent(),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNav() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              step == 1 ? Icons.close : Icons.arrow_back,
              color: const Color(0xFF1E293B),
              size: 28,
            ),
            onPressed: () {
              if (step > 1) {
                setState(() => step--);
              } else {
                _saveDraft();
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 48), // Spacer replacement for symmetry
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    String title;
    switch (step) {
      case 1:
        title = 'Select Category';
        break;
      case 2:
        title = 'General Information';
        break;
      case 3:
        title = 'Service Media';
        break;
      case 4:
        title = 'Set Your Pricing';
        break;
      case 5:
        title = 'Service Add-ons';
        break;
      default:
        title = 'Service Details';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'step $step of $totalSteps',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryIndigo,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width: (MediaQuery.of(context).size.width - 48) * (step / totalSteps),
                decoration: BoxDecoration(
                  color: primaryIndigo,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryIndigo.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (step) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      case 5: return _buildStep5();
      default: return _buildStep1();
    }
  }

  // --- STEP 1: Category Selection ---
  Widget _buildStep1() {
    // Logic to filter categories and subcategories
    List<Map<String, dynamic>> filteredData = [];
    
    for (var cat in _categoryData) {
      if (cat['name'].toLowerCase().contains(_searchQuery.toLowerCase())) {
        // If category matches, include all subs
        filteredData.add(cat);
      } else {
        // Check if any subcategory matches
        List<String> matchingSubs = (cat['subs'] as List<String>)
            .where((sub) => sub.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
            
        if (matchingSubs.isNotEmpty) {
          filteredData.add({
            'name': cat['name'],
            'icon': cat['icon'],
            'subs': matchingSubs,
          });
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of service are you offering?',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
        
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.outfit(fontSize: 15),
            decoration: InputDecoration(
              icon: Icon(Icons.search, color: Colors.grey.shade400),
              hintText: 'Search category or subcategory...',
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredData.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = filteredData[index];
            final String catName = category['name'];
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _searchQuery.isNotEmpty,
                key: PageStorageKey(catName),
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryIndigo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category['icon'], color: primaryIndigo, size: 24),
                ),
                title: Text(
                  catName,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                children: (category['subs'] as List<String>).map((sub) {
                  final String fullSelection = '$catName > $sub';
                  final bool isSelected = selectedCategory == fullSelection;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(68, 0, 24, 0),
                    title: Text(
                      sub,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: isSelected ? primaryIndigo : const Color(0xFF64748B),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected 
                      ? Icon(Icons.check_circle_rounded, color: primaryIndigo, size: 20)
                      : null,
                    onTap: () => setState(() => selectedCategory = fullSelection),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // --- STEP 2: General Info ---
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Service Title'),
        _buildTextField(_titleController, 'e.g., Deep Kitchen Cleaning'),
        const SizedBox(height: 24),
        
        _buildFieldLabel('Service Description'),
        _buildTextField(_descriptionController, 'Describe what your service covers in detail...', maxLines: 5),
        const SizedBox(height: 32),

        _buildFieldLabel("What's Included"),
        Text(
          'List the specific tasks you will perform.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),
        _buildDetailsChecklist(),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- STEP 3: Media ---
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Main Service Picture'),
        Text(
          'This will be the primary image users see in search results.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),
        _buildMainImagePicker(),
        const SizedBox(height: 32),
        
        _buildFieldLabel('Service Gallery (Optional)'),
        Text(
          'Add up to 6 more photos of your previous work.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),
        _buildGalleryPicker(),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- STEP 4: Pricing & Details ---
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          'Base Service Price',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('RM', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: primaryIndigo)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            _priceOptionCard('per hour', Icons.access_time_filled_rounded, 'Flexible pricing based on time.'),
            const SizedBox(width: 16),
            _priceOptionCard('one-time', Icons.receipt_long_rounded, 'Fixed rate for the entire job.'),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _priceOptionCard(String type, IconData icon, String sub) {
    bool isSelected = _priceType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priceType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? primaryIndigo.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryIndigo : Colors.grey.shade100,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? primaryIndigo : Colors.grey.shade400, size: 32),
              const SizedBox(height: 12),
              Text(
                type == 'per hour' ? 'Per Hour' : 'One-time',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? primaryIndigo : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 5: Add-ons ---
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Service Add-ons (Optional)'),
        Text(
          'Offer extra services for an additional fee.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 24),
        _buildAddOnsChecklist(),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- Components ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: GoogleFonts.outfit(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade100)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade100)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryIndigo, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }


  Widget _buildMainImagePicker() {
    return GestureDetector(
      onTap: _pickMainImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          image: _mainImage != null 
            ? DecorationImage(image: FileImage(_mainImage!), fit: BoxFit.cover) 
            : null,
        ),
        child: _mainImage == null ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Upload Main Picture', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ],
        ) : Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 32)),
        ),
      ),
    );
  }

  Widget _buildGalleryPicker() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _galleryImages.length < 6 ? _galleryImages.length + 1 : 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _galleryImages.length && _galleryImages.length < 6) {
          return GestureDetector(
            onTap: _pickGalleryImages,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400),
            ),
          );
        }
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(image: FileImage(_galleryImages[index]), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _galleryImages.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailsChecklist() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(_detailController, 'Add task (e.g., Vacuuming)'),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _addDetail,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: primaryIndigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        if (_serviceDetails.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _serviceDetails.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: primaryIndigo, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _serviceDetails[index],
                        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1E293B)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _serviceDetails.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAddOnsChecklist() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _buildTextField(_addOnNameController, 'Add-on name (e.g., Attic Cleaning)'),
              const SizedBox(height: 12),
              _buildTextField(_addOnDescriptionController, 'Description (e.g., Deep cleaning of the attic floor)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTextField(_addOnPriceController, 'Extra Price (RM)', isNumber: true)),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _addAddOn,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: primaryIndigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_addOns.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addOns.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Container(
                height: 100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: primaryIndigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.plus_one_rounded, color: primaryIndigo, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_addOns[index]['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(_addOns[index]['description'] ?? '', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 12, height: 1.2)),
                          const SizedBox(height: 4),
                          Text('RM ${_addOns[index]['price']}', style: GoogleFonts.outfit(color: primaryIndigo, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                      onPressed: () => setState(() => _addOns.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  bool _isPublishing = false;

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          if (step > 1)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isPublishing ? null : () => setState(() => step--),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade200),
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Back', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
            ),
          if (step > 1) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isPublishing
                  ? null
                  : () {
                      if (step < totalSteps) {
                        setState(() => step++);
                      } else {
                        _publishService();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryIndigo,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      step < totalSteps ? 'Continue' : 'Publish Service',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File? file, String serviceId, String type) async {
    if (file == null) return null;
    try {
      final fileName = path_pkg.basename(file.path);
      final destination = 'services/$serviceId/$type/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref(destination);
      debugPrint('Uploading $type image to $destination...');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Upload success: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading $type image: $e');
      return null;
    }
  }

  Future<void> _publishService() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_titleController.text.trim().isEmpty || 
        selectedCategory == null || 
        _priceController.text.trim().isEmpty ||
        _mainImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all required fields and upload a main image.',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.orangeAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 🔹 1. Fetch Provider Details
      final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
      if (!providerDoc.exists) throw Exception("Provider profile not found. Please complete your registration.");
      final providerData = providerDoc.data()!;
      final String providerName = providerData['name'] ?? 'Elite Pro';
      final String providerAddress = providerData['address'] ?? 'Kuala Lumpur, Malaysia';
      final String providerProfileUrl = providerData['profileUrl'] ?? '';

      // Geocode providerAddress to LatLng
      double providerLat = 0.0;
      double providerLng = 0.0;
      try {
        List<Location> locations = await locationFromAddress(providerAddress);
        if (locations.isNotEmpty) {
          providerLat = locations.first.latitude;
          providerLng = locations.first.longitude;
        }
      } catch (e) {
        debugPrint('Error geocoding provider address: $e');
      }

      // 🔹 2. Create Service ID (if new)
      final CollectionReference servicesCollection = FirebaseFirestore.instance.collection('services');
      DocumentReference serviceDoc;
      final String? existingServiceId = widget.initialDraftData?['serviceId'];
      
      if (existingServiceId != null && existingServiceId.isNotEmpty) {
        serviceDoc = servicesCollection.doc(existingServiceId);
      } else {
        serviceDoc = servicesCollection.doc();
      }

      // 🔹 3. Upload New Images
      String? mainImageUrl = _networkMainImage;
      String? uploadError;
      
      if (_mainImage != null) {
        try {
          mainImageUrl = await _uploadImage(_mainImage, serviceDoc.id, 'main');
          if (mainImageUrl == null) uploadError = "Failed to upload main image. Please check your storage bucket configuration or internet connection.";
        } catch (e) {
          uploadError = e.toString();
        }
        if (uploadError != null) throw Exception(uploadError);
      }
      
      List<String> galleryUrls = List<String>.from(_networkGalleryImages);
      for (var imgFile in _galleryImages) {
        String? url = await _uploadImage(imgFile, serviceDoc.id, 'gallery');
        if (url != null) {
          galleryUrls.add(url);
        } else {
          debugPrint("Warning: A gallery image failed to upload.");
        }
      }

      // 🔹 4. Final Service Data
      final Map<String, dynamic> serviceData = {
        'serviceId': serviceDoc.id,
        'providerId': user.uid,
        'providerName': providerName,
        'providerAddress': providerAddress,
        'providerLat': providerLat,
        'providerLng': providerLng,
        'providerProfileUrl': providerProfileUrl,
        'title': _titleController.text.trim(),
        'category': selectedCategory,
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'priceType': _priceType,
        'details': _serviceDetails,
        'addOns': _addOns,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'servicePhotoUrl': mainImageUrl,
        'galleryUrls': galleryUrls,
      };

      await serviceDoc.set(serviceData, SetOptions(merge: true));

      // 🔹 5. Update Provider's Service List
      List<dynamic> currentServices = providerData['services'] ?? [];
      if (!currentServices.contains(selectedCategory?.split('>').last.trim())) {
        currentServices.add(selectedCategory?.split('>').last.trim());
        await FirebaseFirestore.instance.collection('providers').doc(user.uid).update({
          'services': currentServices,
        });
      }

      // 🔹 6. Delete Draft
      final String? draftId = widget.initialDraftData?['id'];
      if (draftId != null) {
        await AddServiceScreen.clearDraft(draftId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service published successfully!',
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      // Return to dashboard and refresh
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      debugPrint("Publishing error: $e");
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Publishing Failed', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          content: Text(e.toString().replaceAll("Exception: ", ""), style: GoogleFonts.outfit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }
}

class _StepIndicatorDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StepIndicatorDelegate({required this.child});

  @override
  double get minExtent => 90;
  @override
  double get maxExtent => 90;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StepIndicatorDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
