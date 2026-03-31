import 'package:flutter/material.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to capture user input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  // 🔹 NEW: Controllers for Provider Info
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _providerAddressController =
      TextEditingController();

  String? _selectedCategory;
  String? _selectedDuration;

  final List<String> _categories = [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Gardening',
    'Moving',
    'Other',
  ];

  final Map<String, String> _durations = {
    '30': '30 min',
    '60': '1 hour',
    '90': '1.5 hours',
    '120': '2 hours',
    '180': '3 hours',
  };

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final finalCategory =
          _selectedCategory == 'Other'
              ? _customCategoryController.text
              : _selectedCategory;

      debugPrint(
        'New Service: ${_nameController.text} | Provider: ${_providerNameController.text} | Category: $finalCategory',
      );

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Service "${_nameController.text}" added successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
    // 🔹 NEW: Dispose new controllers
    _providerNameController.dispose();
    _providerAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A233A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add New Service",
          style: TextStyle(
            color: Color(0xFF1A233A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Provider Name Field
                _buildLabel("Provider Name"),
                TextFormField(
                  controller: _providerNameController,
                  decoration: _inputDecoration("e.g., John Doe"),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Please enter provider name' : null,
                ),
                const SizedBox(height: 20),

                // 🔹 Provider Address Field
                _buildLabel("Provider Address"),
                TextFormField(
                  controller: _providerAddressController,
                  maxLines: 2,
                  decoration: _inputDecoration("e.g., 123 Main Street, NY"),
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Please enter provider address'
                              : null,
                ),
                const SizedBox(height: 20),

                _buildLabel("Service Name"),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration("e.g., House Cleaning"),
                  validator:
                      (value) => value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 20),

                _buildLabel("Category"),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration("Select category"),
                  dropdownColor: Colors.white,
                  items:
                      _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                  onChanged:
                      (val) => setState(() {
                        _selectedCategory = val;
                        if (val != 'Other') _customCategoryController.clear();
                      }),
                  validator:
                      (value) =>
                          value == null ? 'Please select a category' : null,
                ),

                if (_selectedCategory == 'Other') ...[
                  const SizedBox(height: 20),
                  _buildLabel("Custom Category"),
                  TextFormField(
                    controller: _customCategoryController,
                    decoration: _inputDecoration(
                      "Enter your custom category",
                    ).copyWith(fillColor: const Color(0xFFF0FDFA)),
                    validator:
                        (value) =>
                            value!.isEmpty ? 'Please enter category' : null,
                  ),
                ],
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Price"),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration("0.00").copyWith(
                              prefixText: "RM ",
                              prefixStyle: const TextStyle(
                                color: Color(0xFF1A233A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            validator:
                                (value) => value!.isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Duration"),
                          DropdownButtonFormField<String>(
                            value: _selectedDuration,
                            decoration: _inputDecoration("Select"),
                            dropdownColor: Colors.white,
                            items:
                                _durations.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) =>
                                    setState(() => _selectedDuration = val),
                            validator:
                                (value) => value == null ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildLabel("Description"),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: _inputDecoration("Describe your service..."),
                  validator:
                      (value) =>
                          value!.isEmpty ? 'Please enter description' : null,
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Add Service",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A233A),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 2),
      ),
    );
  }
}
