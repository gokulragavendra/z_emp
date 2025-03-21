// lib/screens/sales_staff/sales_data_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../services/customer_service.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import '../../providers/user_provider.dart';

class SalesDataEntryScreen extends StatefulWidget {
  const SalesDataEntryScreen({Key? key}) : super(key: key);

  @override
  State<SalesDataEntryScreen> createState() => _SalesDataEntryScreenState();
}

class _SalesDataEntryScreenState extends State<SalesDataEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Mandatory fields
  DateTime? _salesDate;
  final TextEditingController _totalCashSalesController =
      TextEditingController();
  final TextEditingController _numberOfCashSalesController =
      TextEditingController();
  final TextEditingController _crNumbersController = TextEditingController();
  CustomerModel? _selectedCustomer;
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _crAmountController = TextEditingController();
  final TextEditingController _productCategoryController =
      TextEditingController();
  List<String> _productCategories = [];
  String? _selectedProductCategory;
  DateTime? _tatDate;

  // New Optional Field: Additional Notes
  final TextEditingController _additionalNotesController =
      TextEditingController();

  // Data lists for products and customers
  List<ProductModel> _allProducts = [];
  List<CustomerModel> _allCustomers = [];

  // Show a loading indicator when performing time-consuming operations
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProductsAndCustomers();
  }

  /// Pull-to-refresh so the user can manually reload products/customers if desired
  Future<void> _handleRefresh() async {
    await _fetchProductsAndCustomers();
  }

  /// Toggles the loading state (over which we show a loading indicator)
  void _setLoading(bool value) {
    if (mounted) {
      setState(() => _isLoading = value);
    }
  }

  /// Shows a dialog to confirm an action
  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _fetchProductsAndCustomers() async {
    final productService = Provider.of<ProductService>(context, listen: false);
    final customerService =
        Provider.of<CustomerService>(context, listen: false);

    _setLoading(true);
    try {
      _allProducts = await productService.getAllProductsOnce();
      _allCustomers = await customerService.getAllCustomersOnce();

      // Extract unique product categories
      final categories = <String>{};
      for (var product in _allProducts) {
        categories.add(product.category);
      }
      setState(() {
        _productCategories = categories.toList()..sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching products/customers: $e')),
        );
      }
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _totalCashSalesController.dispose();
    _numberOfCashSalesController.dispose();
    _crNumbersController.dispose();
    _customerSearchController.dispose();
    _crAmountController.dispose();
    _productCategoryController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for essential fields
    if (_salesDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Sales Date.')),
      );
      return;
    }
    if (_tatDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a TAT Date.')),
      );
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an existing customer.')),
      );
      return;
    }
    if (_selectedProductCategory == null || _selectedProductCategory!.isEmpty) {
      if (_productCategoryController.text.trim().isNotEmpty) {
        _selectedProductCategory = _productCategoryController.text.trim();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Product Category.')),
        );
        return;
      }
    }

    // Confirm with the user before finalizing
    final confirm = await _showConfirmationDialog(
      'Save Sales Data',
      'Are you sure you want to save this sales data?',
    );
    if (!confirm) return;

    final salesService = Provider.of<SalesService>(context, listen: false);
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User not logged in. Please login again.')),
      );
      return;
    }

    _setLoading(true);
    try {
      // Build the data map (using DateTime, not Timestamp)
      final docId = FirebaseFirestore.instance.collection('sales').doc().id;
      final data = {
        'saleId': docId,
        'salesDate': _salesDate, // DateTime (mandatory)
        'totalCashSales': double.parse(_totalCashSalesController.text.trim()),
        'numberOfCashSales':
            int.parse(_numberOfCashSalesController.text.trim()),
        'crNumbers': _crNumbersController.text.trim(),
        'customerName': _selectedCustomer!.name,
        'customerId': _selectedCustomer!.customerId,
        'crAmount': double.parse(_crAmountController.text.trim()),
        'productCategory': _selectedProductCategory,
        'tatDate': _tatDate, // DateTime (mandatory)
        'createdBy': currentUser.userId,
        'createdAt': DateTime.now(),
        // IMPORTANT: Add assignedSalesPersonId so other queries can match:
        'assignedSalesPersonId': currentUser.userId,

        // New optional field: additionalNotes
        'additionalNotes': _additionalNotesController.text.trim().isEmpty
            ? null
            : _additionalNotesController.text.trim(),
      };

      try {
        await salesService.saveMinimalSalesData(docId, data);
      } catch (e, stack) {
        debugPrint('Error in saveMinimalSalesData: $e');
        debugPrint('Stack Trace:\n$stack');
        rethrow; // pass the error to outer catch
      }

      // Reset the form after successful save
      _formKey.currentState!.reset();
      setState(() {
        _salesDate = null;
        _tatDate = null;
        _selectedCustomer = null;
        _selectedProductCategory = null;
      });
      _totalCashSalesController.clear();
      _numberOfCashSalesController.clear();
      _crNumbersController.clear();
      _customerSearchController.clear();
      _crAmountController.clear();
      _productCategoryController.clear();
      _additionalNotesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales data saved successfully!')),
      );
    } catch (e, stack) {
      // Enhanced error handling
      debugPrint('Error saving data: $e');
      debugPrint('Stack Trace:\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    } finally {
      _setLoading(false);
    }
  }

  Widget _buildSalesDatePicker() {
    final label = _salesDate == null
        ? 'Select Sales Date'
        : 'Sales Date: ${DateFormat('yyyy-MM-dd').format(_salesDate!)}';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final now = DateTime.now();
        final firstDate = DateTime(now.year - 2);
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: firstDate,
          lastDate: now,
        );
        if (picked != null) {
          setState(() => _salesDate = picked);
        }
      },
      validator: (_) {
        if (_salesDate == null) {
          return 'Please select a Sales Date';
        }
        return null;
      },
    );
  }

  Widget _buildTatDatePicker() {
    final label = _tatDate == null
        ? 'Select TAT Date'
        : 'TAT Date: ${DateFormat('yyyy-MM-dd').format(_tatDate!)}';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now,
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) {
          setState(() => _tatDate = picked);
        }
      },
      validator: (_) {
        if (_tatDate == null) {
          return 'Please select a TAT Date';
        }
        return null;
      },
    );
  }

  Widget _buildCustomerSelector() {
    return Autocomplete<CustomerModel>(
      optionsBuilder: (TextEditingValue textValue) {
        if (textValue.text.isEmpty) {
          return const Iterable<CustomerModel>.empty();
        }
        return _allCustomers.where((cust) =>
            cust.name.toLowerCase().contains(textValue.text.toLowerCase()));
      },
      displayStringForOption: (CustomerModel cust) => cust.name,
      fieldViewBuilder:
          (context, textController, focusNode, onEditingComplete) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Select Existing Customer',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (_selectedCustomer == null) {
              return 'Please select a customer';
            }
            return null;
          },
        );
      },
      onSelected: (CustomerModel selection) {
        setState(() {
          _selectedCustomer = selection;
        });
      },
    );
  }

  Widget _buildProductCategoryField() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textValue) {
        if (textValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final input = textValue.text.toLowerCase();
        return _productCategories
            .where((cat) => cat.toLowerCase().contains(input));
      },
      fieldViewBuilder:
          (context, textController, focusNode, onEditingComplete) {
        _productCategoryController.text = textController.text;
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Product Category',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: () {
            setState(() {
              _selectedProductCategory = textController.text.trim();
            });
            onEditingComplete();
          },
          validator: (val) {
            if (_selectedProductCategory == null ||
                _selectedProductCategory!.isEmpty) {
              return 'Please select a product category';
            }
            return null;
          },
        );
      },
      onSelected: (String selection) {
        setState(() {
          _selectedProductCategory = selection;
        });
      },
    );
  }

  Widget _buildAdditionalNotesField() {
    return TextFormField(
      controller: _additionalNotesController,
      decoration: const InputDecoration(
        labelText: 'Additional Notes (Optional)',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Sales Data Entry'),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Pull-to-refresh to let user reload products/customers if they desire
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _isLoading
                ? const SingleChildScrollView(
                    // If _isLoading is true, we still want scrollable widget
                    // so the refresh can be triggered, even though we show spinner
                    child: SizedBox(
                      height: 600,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Enter Sales Data',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              _buildSalesDatePicker(),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _totalCashSalesController,
                                decoration: const InputDecoration(
                                  labelText: 'Total Cash Sales',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter total cash sales';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _numberOfCashSalesController,
                                decoration: const InputDecoration(
                                  labelText: 'Number of Cash Sales',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter number of cash sales';
                                  }
                                  if (int.tryParse(value.trim()) == null) {
                                    return 'Invalid integer';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _crNumbersController,
                                decoration: const InputDecoration(
                                  labelText: 'CR Numbers',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter CR numbers';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildCustomerSelector(),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _crAmountController,
                                decoration: const InputDecoration(
                                  labelText: 'CR Amount',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter CR amount';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildProductCategoryField(),
                              const SizedBox(height: 16),
                              _buildTatDatePicker(),
                              const SizedBox(height: 16),
                              _buildAdditionalNotesField(),
                              const SizedBox(height: 24),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _submitForm,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Sales Data'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    textStyle: const TextStyle(fontSize: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        // If we want an overlay spinner for additional tasks, we could do so here,
        // but we've simply used a direct progress indicator in the content above.
      ],
    );
  }
}
