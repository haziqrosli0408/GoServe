import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path_pkg;

class EditServiceScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;
  const EditServiceScreen({super.key, required this.serviceData});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _addOnNameController = TextEditingController();
  final TextEditingController _addOnPriceController = TextEditingController();
  final TextEditingController _addOnDescriptionController = TextEditingController();

  // State Variables
  String? _selectedCategory;
  String _priceType = 'per hour';
  
  // Local Files (New uploads)
  dynamic _newMainImage; // File or XFile
  final List<dynamic> _newGalleryImages = []; // List<File> or List<XFile>
  
  // Network URLs (Existing data)
  String? _existingMainImageUrl;
  List<String> _existingGalleryUrls = [];
  
  // Collections
  final List<String> _serviceDetails = [];
  final List<Map<String, dynamic>> _addOns = [];

  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();
  final Color primaryIndigo = const Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    final data = widget.serviceData;
    
    // Initialize Controllers
    _titleController = TextEditingController(text: data['title'] ?? '');
    _priceController = TextEditingController(text: data['price'] ?? '');
    _descriptionController = TextEditingController(text: data['description'] ?? '');
    
    // Initialize Data
    _selectedCategory = data['category'];
    _priceType = data['priceType'] ?? 'per hour';
    _existingMainImageUrl = data['servicePhotoUrl'];
    
    if (data['galleryUrls'] != null) {
      _existingGalleryUrls = List<String>.from(data['galleryUrls']);
    }
    if (data['details'] != null) {
      _serviceDetails.addAll(List<String>.from(data['details']));
    }
    if (data['addOns'] != null) {
      _addOns.addAll(List<Map<String, dynamic>>.from(data['addOns']));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _detailController.dispose();
    _addOnNameController.dispose();
    _addOnPriceController.dispose();
    _addOnDescriptionController.dispose();
    super.dispose();
  }

  // --- Image Pickers ---
  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      setState(() => _newMainImage = kIsWeb ? image : File(image.path));
    }
  }

  Future<void> _pickGalleryImages() async {
    final int totalCount = _existingGalleryUrls.length + _newGalleryImages.length;
    if (totalCount >= 6) return;
    
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (images.isNotEmpty) {
      setState(() {
        for (var image in images) {
          if (_existingGalleryUrls.length + _newGalleryImages.length < 6) {
            _newGalleryImages.add(kIsWeb ? image : File(image.path));
          }
        }
      });
    }
  }

  // --- Firestore Logic ---
  Future<String?> _uploadImage(dynamic file, String serviceId, String type) async {
    if (file == null) return null;
    try {
      final String fileName = kIsWeb ? (file as XFile).name : path_pkg.basename((file as File).path);
      final destination = 'services/$serviceId/$type/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref(destination);
      
      TaskSnapshot uploadTask;
      if (kIsWeb) {
        uploadTask = await ref.putData(await (file as XFile).readAsBytes());
      } else {
        uploadTask = await ref.putFile(file as File);
      }
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty || _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String serviceId = widget.serviceData['id'] ?? widget.serviceData['serviceId'];
      final docRef = FirebaseFirestore.instance.collection('services').doc(serviceId);

      // Upload new images if any
      String? mainImageUrl = _existingMainImageUrl;
      if (_newMainImage != null) {
        mainImageUrl = await _uploadImage(_newMainImage, serviceId, 'main');
      }

      List<String> finalGalleryUrls = List<String>.from(_existingGalleryUrls);
      for (var file in _newGalleryImages) {
        final url = await _uploadImage(file, serviceId, 'gallery');
        if (url != null) finalGalleryUrls.add(url);
      }

      final Map<String, dynamic> updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'priceType': _priceType,
        'details': _serviceDetails,
        'addOns': _addOns,
        'servicePhotoUrl': mainImageUrl,
        'galleryUrls': finalGalleryUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(updateData);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Service?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Text(
            'This action cannot be undone. This service will be permanently removed from your listing.',
            style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final String serviceId =
            widget.serviceData['id'] ?? widget.serviceData['serviceId'];
        await FirebaseFirestore.instance
            .collection('services')
            .doc(serviceId)
            .delete();

        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting service: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.grey.shade100,
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Service',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed: _saveChanges,
                  child: Text(
                    'Save',
                    style: GoogleFonts.outfit(
                      color: primaryIndigo,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Category (Read Only) ---
            _buildFieldLabel('Category'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    _selectedCategory ?? 'No Category Set',
                    style: GoogleFonts.outfit(
                        color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- General Info ---
            _buildFieldLabel('Service Title'),
            _buildTextField(_titleController, 'e.g., House Cleaning'),
            const SizedBox(height: 24),

            _buildFieldLabel('Description'),
            _buildTextField(_descriptionController, 'Describe your service...',
                maxLines: 5),
            const SizedBox(height: 32),

            // --- Media Section ---
            _buildFieldLabel('Main Service Image'),
            const SizedBox(height: 12),
            _buildMainImageSection(),
            const SizedBox(height: 24),

            _buildFieldLabel('Service Gallery'),
            const SizedBox(height: 12),
            _buildGallerySection(),
            const SizedBox(height: 32),

            // --- Pricing ---
            _buildFieldLabel('Pricing'),
            const SizedBox(height: 12),
            _buildPricingSection(),
            const SizedBox(height: 32),

            // --- Checklist/Addons ---
            _buildFieldLabel('Service Details'),
            _buildDetailsEditor(),
            const SizedBox(height: 32),

            _buildFieldLabel('Add-ons (Optional)'),
            _buildAddOnsEditor(),
            const SizedBox(height: 48),

            // 🔹 DELETE BUTTON
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _deleteService,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                label: Text(
                  'Delete Service',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Form Components ---

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Light grey for text fields
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade100)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade100)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryIndigo)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildMainImageSection() {
    bool hasImage = _newMainImage != null || _existingMainImageUrl != null;
    return GestureDetector(
      onTap: _pickMainImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          image: hasImage 
            ? DecorationImage(
                image: _newMainImage != null 
                  ? (kIsWeb ? NetworkImage((_newMainImage as XFile).path) : FileImage(_newMainImage as File) as ImageProvider)
                  : NetworkImage(_existingMainImageUrl!) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
        ),
        child: !hasImage 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.shade300),
                Text('Add Photo', style: GoogleFonts.outfit(color: Colors.grey.shade500)),
              ],
            )
          : Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.edit_rounded, color: primaryIndigo, size: 20),
              ),
            ),
      ),
    );
  }

  Widget _buildGallerySection() {
    int totalCount = _existingGalleryUrls.length + _newGalleryImages.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCount < 6 ? totalCount + 1 : 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        if (index == totalCount && totalCount < 6) {
          return GestureDetector(
            onTap: _pickGalleryImages,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Icon(Icons.add_rounded, color: Colors.grey.shade400),
            ),
          );
        }

        // Show existing or new images
        final bool isExisting = index < _existingGalleryUrls.length;
        final ImageProvider provider = isExisting
          ? NetworkImage(_existingGalleryUrls[index])
          : (kIsWeb ? NetworkImage((_newGalleryImages[index - _existingGalleryUrls.length] as XFile).path) : FileImage(_newGalleryImages[index - _existingGalleryUrls.length] as File));

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(image: provider, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExisting) {
                      _existingGalleryUrls.removeAt(index);
                    } else {
                      _newGalleryImages.removeAt(index - _existingGalleryUrls.length);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('RM', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: primaryIndigo)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _priceTypeChip('per hour'),
              const SizedBox(width: 8),
              _priceTypeChip('one-time'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceTypeChip(String type) {
    bool isSelected = _priceType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priceType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryIndigo : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? primaryIndigo : Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              type == 'per hour' ? 'Per Hour' : 'One-time',
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsEditor() {
    return Column(
      children: [
        ..._serviceDetails.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.value, style: GoogleFonts.outfit(fontSize: 14))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => setState(() => _serviceDetails.removeAt(entry.key)),
                ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Expanded(child: _buildTextField(_detailController, 'Add specific task (e.g., Sweeping)')),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: primaryIndigo, size: 32),
              onPressed: () {
                if (_detailController.text.trim().isNotEmpty) {
                  setState(() {
                    _serviceDetails.add(_detailController.text.trim());
                    _detailController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddOnsEditor() {
    return Column(
      children: [
        ..._addOns.asMap().entries.map((entry) {
          return Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryIndigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.plus_one_rounded, color: primaryIndigo, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(entry.value['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(entry.value['description'] ?? '', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('RM ${entry.value['price']}', style: GoogleFonts.outfit(color: primaryIndigo, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => setState(() => _addOns.removeAt(entry.key)),
                ),
              ],
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_addOnNameController, 'Add-on Name (e.g., Carpet cleaning)'),
              const SizedBox(height: 12),
              _buildTextField(_addOnPriceController, 'Price (RM)', isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_addOnDescriptionController, 'Short description of this add-on', maxLines: 2),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_addOnNameController.text.isNotEmpty && _addOnPriceController.text.isNotEmpty) {
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryIndigo,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Add Item', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
