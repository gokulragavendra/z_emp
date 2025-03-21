import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/product_model.dart';
import '../../services/product_service.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subcategoryController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _managerDiscountController =
      TextEditingController();
  final TextEditingController _salesmanDiscountController =
      TextEditingController();

  File? _selectedImage;

  // Sets to store existing categories and subcategories
  Set<String> _existingCategories = {};
  Set<String> _existingSubcategories = {};

  bool _isOperationInProgress = false; // For overlay spinner (Add Product)
  bool _isImportingCsv = false; // For overlay spinner (Import CSV)

  @override
  void initState() {
    super.initState();
    _fetchExistingCategoriesAndSubcategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _subcategoryController.dispose();
    _itemNameController.dispose();
    _codeController.dispose();
    _mrpController.dispose();
    _taxController.dispose();
    _managerDiscountController.dispose();
    _salesmanDiscountController.dispose();
    super.dispose();
  }

  /// Fetches existing categories and subcategories to populate the autocomplete fields
  Future<void> _fetchExistingCategoriesAndSubcategories() async {
    try {
      final productService =
          Provider.of<ProductService>(context, listen: false);
      final products = await productService.getAllProductsOnce();
      if (!mounted) return;
      setState(() {
        _existingCategories = products.map((e) => e.category).toSet();
        _existingSubcategories = products.map((e) => e.subcategory).toSet();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching existing categories: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Import CSV Button
                ElevatedButton.icon(
                  onPressed: _confirmImportCsv,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Products from CSV'),
                ),
                const SizedBox(height: 20),
                // Add Product Button
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product Manually'),
                ),
              ],
            ),
          ),
          // If adding a product or importing CSV, show a loading overlay
          if (_isOperationInProgress || _isImportingCsv)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Asks the user for confirmation before importing from CSV
  Future<void> _confirmImportCsv() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm CSV Import'),
          content:
              const Text('Do you want to import products from a CSV file?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _importCsv();
    }
  }

  /// Imports products from a user-selected CSV file
  Future<void> _importCsv() async {
    setState(() => _isImportingCsv = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        final file = File(result.files.single.path!);
        final csvContent = await file.readAsString();
        final rows = const LineSplitter().convert(csvContent);

        final productService =
            Provider.of<ProductService>(context, listen: false);

        int addedCount = 0;
        int updatedCount = 0;

        // Skip header row
        for (int i = 1; i < rows.length; i++) {
          final fields = _parseCsvRow(rows[i]);
          if (fields.length < 9) continue;

          final category = fields[0];
          final subcategory = fields[1];
          final itemName = fields[2];
          final code = fields[3];
          final mrp = double.tryParse(fields[4]) ?? 0.0;
          final tax = double.tryParse(fields[5]) ?? 0.0;
          final imageUrl = fields[6];
          final managerDiscount = double.tryParse(fields[7]) ?? 0.0;
          final salesmanDiscount = double.tryParse(fields[8]) ?? 0.0;

          final existingProduct = await productService.getProductByCode(code);

          if (existingProduct != null) {
            // Update existing product
            final updatedData = {
              'category': category,
              'subcategory': subcategory,
              'itemName': itemName,
              'mrp': mrp,
              'tax': tax,
              'imageUrl': imageUrl,
              'managerDiscount': managerDiscount,
              'salesmanDiscount': salesmanDiscount,
            };
            await productService.updateProduct(
              existingProduct.id,
              updatedData,
              null,
            );
            updatedCount++;
          } else {
            // Add new product
            final newProduct = ProductModel(
              id: '',
              category: category,
              subcategory: subcategory,
              itemName: itemName,
              code: code,
              mrp: mrp,
              tax: tax,
              imageUrl: imageUrl,
              managerDiscount: managerDiscount,
              salesmanDiscount: salesmanDiscount,
            );
            await productService.addProduct(newProduct, null);
            addedCount++;
          }
        }

        // Refresh existing categories/subcategories
        await _fetchExistingCategoriesAndSubcategories();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Products imported successfully. '
              '$addedCount added, $updatedCount updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import products: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingCsv = false);
      }
    }
  }

  /// Parses a row of CSV text, carefully handling commas inside quotes
  List<String> _parseCsvRow(String row) {
    final fields = <String>[];
    var inQuotes = false;
    final field = StringBuffer();

    for (int i = 0; i < row.length; i++) {
      if (row[i] == '"') {
        inQuotes = !inQuotes;
      } else if (row[i] == ',' && !inQuotes) {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(row[i]);
      }
    }
    fields.add(field.toString());
    return fields.map((f) => f.trim().replaceAll('"', '')).toList();
  }

  /// Displays a dialog to add a single product
  void _showAddProductDialog() {
    _clearControllers();
    _selectedImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildAutocompleteField(
                  controller: _categoryController,
                  label: 'Category',
                  options: _existingCategories.toList(),
                ),
                _buildAutocompleteField(
                  controller: _subcategoryController,
                  label: 'Subcategory',
                  options: _existingSubcategories.toList(),
                ),
                _buildTextField(_itemNameController, 'Item Name'),
                _buildTextField(_codeController, 'Code'),
                _buildTextField(_mrpController, 'MRP', isNumber: true),
                _buildTextField(_taxController, 'Tax (%)', isNumber: true),
                _buildTextField(
                  _managerDiscountController,
                  'Manager Discount (%)',
                  isNumber: true,
                ),
                _buildTextField(
                  _salesmanDiscountController,
                  'Salesman Discount (%)',
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _buildImagePicker(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _confirmAddProduct,
              child: const Text('Add Product'),
            ),
          ],
        );
      },
    );
  }

  /// Confirms the addition of a product with a dialog
  Future<void> _confirmAddProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Add'),
          content: const Text('Are you sure you want to add this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _addProduct();
    }
  }

  /// Actually adds the product after user confirms
  Future<void> _addProduct() async {
    setState(() => _isOperationInProgress = true);

    final product = ProductModel(
      id: '',
      category: _categoryController.text.trim(),
      subcategory: _subcategoryController.text.trim(),
      itemName: _itemNameController.text.trim(),
      code: _codeController.text.trim(),
      mrp: double.tryParse(_mrpController.text.trim()) ?? 0.0,
      tax: double.tryParse(_taxController.text.trim()) ?? 0.0,
      managerDiscount:
          double.tryParse(_managerDiscountController.text.trim()) ?? 0.0,
      salesmanDiscount:
          double.tryParse(_salesmanDiscountController.text.trim()) ?? 0.0,
      imageUrl: '',
    );

    try {
      final productService =
          Provider.of<ProductService>(context, listen: false);
      await productService.addProduct(product, _selectedImage);

      // Refresh existing categories/subcategories
      await _fetchExistingCategoriesAndSubcategories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        _clearControllers();
        Navigator.pop(context); // Closes the Add Product dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  /// Clears all text fields and resets the image selection
  void _clearControllers() {
    _categoryController.clear();
    _subcategoryController.clear();
    _itemNameController.clear();
    _codeController.clear();
    _mrpController.clear();
    _taxController.clear();
    _managerDiscountController.clear();
    _salesmanDiscountController.clear();
    _selectedImage = null;
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final picker = ImagePicker();
              final pickedFile =
                  await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                setState(() => _selectedImage = File(pickedFile.path));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error picking image: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.image),
          label: const Text('Select Image'),
        ),
        if (_selectedImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Image.file(
              _selectedImage!,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required List<String> options,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          } else {
            return options.where((String option) {
              return option
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          }
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          // Sync the Autocomplete's text field with the given controller
          textEditingController.text = controller.text;
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: label),
            onChanged: (val) {
              controller.text = val;
            },
          );
        },
      ),
    );
  }
}
