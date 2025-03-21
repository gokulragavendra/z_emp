// lib/screens/sales_staff/job_enquiry_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/enquiry_service.dart';
import '../../models/enquiry_model.dart';
import '../../services/customer_service.dart';
import '../../models/customer_model.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../providers/user_provider.dart';

class JobEnquiryScreen extends StatefulWidget {
  const JobEnquiryScreen({super.key});

  @override
  State<JobEnquiryScreen> createState() => _JobEnquiryScreenState();
}

class _JobEnquiryScreenState extends State<JobEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for various fields
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController regionController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController enquiryNameController = TextEditingController();
  final TextEditingController specificProductSceneController =
      TextEditingController();

  bool isExistingCustomer = false;
  CustomerModel? selectedCustomer;
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerEmailController = TextEditingController();
  final TextEditingController customerAddressController =
      TextEditingController();

  List<ProductModel> products = [];
  List<String> productCategories = [];
  String? selectedProductCategory;

  String status = 'Enquiry';
  DateTime? enquiryDate;
  String? selectedMeasurementStaff;

  final TextEditingController numMaleCustomersController =
      TextEditingController();
  final TextEditingController numFemaleCustomersController =
      TextEditingController();
  final TextEditingController numChildrenCustomersController =
      TextEditingController();

  List<CustomerModel> customers = [];

  // Displays an overlay loading indicator for time-consuming tasks
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCustomers();
  }

  /// Toggles our loading overlay
  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  /// Shows a confirmation dialog with a given [title] and [message].
  /// Returns true if the user confirms, otherwise false.
  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
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

  Future<void> _loadProducts() async {
    final productService = Provider.of<ProductService>(context, listen: false);
    final fetchedProducts = await productService.getAllProductsOnce();
    if (!mounted) return;
    setState(() {
      products = fetchedProducts;
      _extractCategories();
    });
  }

  Future<void> _loadCustomers() async {
    final customerService =
        Provider.of<CustomerService>(context, listen: false);
    final fetchedCustomers = await customerService.getAllCustomersOnce();
    if (!mounted) return;
    setState(() {
      customers = fetchedCustomers;
    });
  }

  void _extractCategories() {
    final categories = products.map((p) => p.category).toSet().toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    productCategories = categories;
  }

  // Pull-to-refresh handler: re-load products/customers (adjust as needed)
  Future<void> _handleRefresh() async {
    await _loadProducts();
    await _loadCustomers();
    // Add any additional data refresh logic here
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<String>> statusItems = [
      const DropdownMenuItem(value: 'Enquiry', child: Text('Enquiry')),
      const DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
    ];

    // We use a Stack to allow for an overlay when _isLoading is true
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Job Enquiries')),
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              // Allows pull-down to trigger the refresh even if content is short
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Create New Job Enquiry',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16.0),
                    _buildCustomerSelection(),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText:
                            'Enquiry Date * ${enquiryDate != null ? '(${DateFormat('yyyy-MM-dd').format(enquiryDate!)})' : ''}',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        DateTime initialDate = enquiryDate ?? DateTime.now();
                        DateTime firstDate = DateTime(2000);
                        DateTime lastDate = DateTime.now();

                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );

                        if (pickedDate != null && pickedDate != enquiryDate) {
                          if (!mounted) return;
                          setState(() {
                            enquiryDate = pickedDate;
                          });
                        }
                      },
                      validator: (value) => enquiryDate == null
                          ? 'Please select enquiry date'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: regionController,
                      decoration: const InputDecoration(
                        labelText: 'Area *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter area'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return productCategories.where((category) => category
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Product Category *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (selectedProductCategory == null ||
                                      selectedProductCategory!.isEmpty)
                                  ? 'Please select a product category'
                                  : null,
                        );
                      },
                      onSelected: (String selection) {
                        if (!mounted) return;
                        setState(() {
                          selectedProductCategory = selection;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: specificProductSceneController,
                      decoration: const InputDecoration(
                        labelText: 'Specific Product Scene *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter specific product scene'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    _buildNumberOfCustomersSection(),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: statusItems,
                      onChanged: (value) {
                        if (value != null) {
                          if (!mounted) return;
                          setState(() {
                            status = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please select a status'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Ask for confirmation before proceeding
                          final confirmed = await _showConfirmationDialog(
                            'Save Enquiry',
                            'Are you sure you want to save this new job enquiry?',
                          );
                          if (!confirmed) return;

                          _setLoading(true);
                          try {
                            final enquiryService = Provider.of<EnquiryService>(
                              context,
                              listen: false,
                            );
                            final customerService =
                                Provider.of<CustomerService>(
                              context,
                              listen: false,
                            );
                            final currentUser = Provider.of<UserProvider>(
                                    context,
                                    listen: false)
                                .user;
                            String customerId = '';

                            if (isExistingCustomer &&
                                selectedCustomer != null) {
                              customerId = selectedCustomer!.customerId;
                            }

                            if (!isExistingCustomer) {
                              final newCustomerId = FirebaseFirestore.instance
                                  .collection('customers')
                                  .doc()
                                  .id;
                              final newCustomer = CustomerModel(
                                customerId: newCustomerId,
                                name: customerNameController.text,
                                phone: phoneNumberController.text,
                                email: customerEmailController.text,
                                address: customerAddressController.text,
                                registrationDate: Timestamp.now(),
                              );
                              await customerService.addCustomer(newCustomer);
                              customerId = newCustomerId;
                              if (!mounted) return;
                            }

                            final enquiryId = FirebaseFirestore.instance
                                .collection('enquiries')
                                .doc()
                                .id;

                            final newEnquiry = EnquiryModel(
                              enquiryId: enquiryId,
                              enquiryName: selectedProductCategory ?? 'No Name',
                              customerId: customerId,
                              customerName: isExistingCustomer
                                  ? selectedCustomer?.name ?? ''
                                  : customerNameController.text,
                              phoneNumber: isExistingCustomer
                                  ? selectedCustomer?.phone ?? ''
                                  : phoneNumberController.text,
                              customerEmail: customerEmailController.text,
                              customerAddress: isExistingCustomer
                                  ? selectedCustomer?.address ?? ''
                                  : customerAddressController.text,
                              region: regionController.text,
                              product: selectedProductCategory ?? '',
                              assignedSalesPerson: currentUser?.name ?? '',
                              assignedSalesPersonId: currentUser?.userId ?? '',
                              numMaleCustomers: int.tryParse(
                                    numMaleCustomersController.text,
                                  ) ??
                                  0,
                              numFemaleCustomers: int.tryParse(
                                    numFemaleCustomersController.text,
                                  ) ??
                                  0,
                              numChildrenCustomers: int.tryParse(
                                    numChildrenCustomersController.text,
                                  ) ??
                                  0,
                              status: status,
                              remarks: remarksController.text,
                              enquiryDate: Timestamp.fromDate(enquiryDate!),
                              timeIn: Timestamp.now(),
                              timeOut: null,
                              assignedMeasurementStaff: null,
                              specificProductScene:
                                  specificProductSceneController.text,
                            );

                            await enquiryService.createJobEnquiry(newEnquiry);
                            if (!mounted) return;

                            _formKey.currentState!.reset();
                            if (!mounted) return;
                            setState(() {
                              isExistingCustomer = false;
                              selectedCustomer = null;
                              selectedProductCategory = null;
                              enquiryDate = null;
                              status = 'Enquiry';
                              selectedMeasurementStaff = null;
                              phoneNumberController.clear();
                              remarksController.clear();
                              regionController.clear();
                              customerNameController.clear();
                              customerEmailController.clear();
                              customerAddressController.clear();
                              numMaleCustomersController.clear();
                              numFemaleCustomersController.clear();
                              numChildrenCustomersController.clear();
                              specificProductSceneController.clear();
                            });

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Job enquiry created successfully'),
                              ),
                            );
                          } catch (e) {
                            // Enhanced error handling
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error creating job enquiry: $e'),
                                ),
                              );
                            }
                          } finally {
                            _setLoading(false);
                          }
                        }
                      },
                      child: const Text('Save Enquiry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Show a loading overlay when _isLoading = true
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Type:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Existing'),
              selected: isExistingCustomer,
              onSelected: (selected) {
                if (!mounted) return;
                setState(() {
                  isExistingCustomer = true;
                  selectedCustomer = null;
                  customerNameController.clear();
                  customerEmailController.clear();
                  customerAddressController.clear();
                  phoneNumberController.clear();
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('New'),
              selected: !isExistingCustomer,
              onSelected: (selected) {
                if (!mounted) return;
                setState(() {
                  isExistingCustomer = false;
                  selectedCustomer = null;
                  customerNameController.clear();
                  customerEmailController.clear();
                  customerAddressController.clear();
                  phoneNumberController.clear();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isExistingCustomer)
          Column(
            children: [
              Autocomplete<CustomerModel>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<CustomerModel>.empty();
                  }
                  return customers.where((CustomerModel customer) => customer
                      .name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (CustomerModel option) => option.name,
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        selectedCustomer == null && isExistingCustomer
                            ? 'Please select a customer'
                            : null,
                  );
                },
                onSelected: (CustomerModel selection) {
                  if (!mounted) return;
                  setState(() {
                    selectedCustomer = selection;
                    customerNameController.text = selection.name;
                    customerEmailController.text = selection.email;
                    customerAddressController.text = selection.address;
                    phoneNumberController.text = selection.phone;
                  });
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: customerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: customerAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Phone number is required'
                    : null,
              ),
              const SizedBox(height: 16.0),
            ],
          )
        else
          Column(
            children: [
              TextFormField(
                controller: customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter customer name'
                    : null,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: customerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: customerAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter an address'
                    : null,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
            ],
          ),
      ],
    );
  }

  Widget _buildNumberOfCustomersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Number of Customers:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: numMaleCustomersController,
                decoration: const InputDecoration(
                  labelText: 'Male',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: TextFormField(
                controller: numFemaleCustomersController,
                decoration: const InputDecoration(
                  labelText: 'Female',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: TextFormField(
                controller: numChildrenCustomersController,
                decoration: const InputDecoration(
                  labelText: 'Children',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    phoneNumberController.dispose();
    regionController.dispose();
    remarksController.dispose();
    customerNameController.dispose();
    customerEmailController.dispose();
    customerAddressController.dispose();
    numMaleCustomersController.dispose();
    numFemaleCustomersController.dispose();
    numChildrenCustomersController.dispose();
    enquiryNameController.dispose();
    specificProductSceneController.dispose();
    super.dispose();
  }
}
