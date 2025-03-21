// lib/screens/measurement_staff/task_logging_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/measurement_service.dart';
import '../../models/task_model.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import 'package:intl/intl.dart';
import '../../services/enquiry_service.dart';
import '../../models/enquiry_model.dart';
import '../../services/customer_service.dart';
import '../../models/customer_model.dart';

class TaskLoggingScreen extends StatefulWidget {
  const TaskLoggingScreen({super.key});

  @override
  State<TaskLoggingScreen> createState() => _TaskLoggingScreenState();
}

class _TaskLoggingScreenState extends State<TaskLoggingScreen> {
  final TextEditingController crNumberController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController tatController = TextEditingController();

  DateTime? measurementDate;
  List<ProductModel> products = [];
  ProductModel? selectedProductForTask;

  Map<String, CustomerModel> customerCache = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final productService = Provider.of<ProductService>(context, listen: false);
    final fetchedProducts = await productService.getAllProductsOnce();
    if (!mounted) return;
    setState(() {
      products = fetchedProducts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final measurementService = Provider.of<MeasurementService>(context, listen: false);
    final enquiryService = Provider.of<EnquiryService>(context, listen: false);
    final customerService = Provider.of<CustomerService>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Measurement Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Assigned Measurement Tasks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: measurementService.getAssignedTasks('MTBT', userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return _buildErrorWidget();
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyWidget('No assigned measurement tasks found.');
                  } else {
                    final tasks = snapshot.data!;
                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          title: Text('Task: ${task.title}'),
                          subtitle: Text('Status: ${task.status}'),
                          trailing: Text(DateFormat('yyyy-MM-dd').format(task.createdAt.toDate())),
                          onTap: () => _showTaskDetailsDialog(
                              context, task, measurementService, enquiryService, customerService),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Completed Measurement Tasks (MOK)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: measurementService.getCompletedTasks('MOK', userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return _buildErrorWidget();
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyWidget('No completed measurement tasks found.');
                  } else {
                    final completedTasks = snapshot.data!;
                    return ListView.builder(
                      itemCount: completedTasks.length,
                      itemBuilder: (context, index) {
                        final task = completedTasks[index];
                        return FutureBuilder<CustomerModel?>(
                          future: _getCustomerForTask(task, enquiryService, customerService),
                          builder: (context, customerSnapshot) {
                            String customerName = '';
                            String customerEmail = '';
                            String customerPhone = '';
                            String customerAddress = '';

                            if (customerSnapshot.connectionState == ConnectionState.waiting) {
                              customerName = 'Loading...';
                            } else if (customerSnapshot.hasError || !customerSnapshot.hasData) {
                              customerName = 'Unavailable';
                            } else {
                              final customer = customerSnapshot.data!;
                              customerName = customer.name;
                              customerEmail = customer.email;
                              customerPhone = customer.phone;
                              customerAddress = customer.address;
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 3,
                              child: ListTile(
                                title: Text('Task: ${task.title}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${task.status}'),
                                    Text('Measurement Date: ${task.measurementDate != null ? DateFormat('yyyy-MM-dd').format(task.measurementDate!.toDate()) : '-'}'),
                                    const SizedBox(height: 4.0),
                                    Text('Customer: $customerName'),
                                    Text('Email: $customerEmail'),
                                    Text('Phone: $customerPhone'),
                                    Text('Address: $customerAddress'),
                                  ],
                                ),
                                trailing: task.measurementDate != null
                                    ? Text(DateFormat('yyyy-MM-dd').format(task.measurementDate!.toDate()))
                                    : const Text('-'),
                                isThreeLine: true,
                                onTap: () => _showCompletedTaskDetailsDialog(
                                    context, task, customerSnapshot.data),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<CustomerModel?> _getCustomerForTask(
      TaskModel task,
      EnquiryService enquiryService,
      CustomerService customerService) async {
    EnquiryModel? enquiry = await enquiryService.getEnquiryById(task.enquiryId);
    if (enquiry == null) return null;
    String customerId = enquiry.customerId;

    if (customerCache.containsKey(customerId)) {
      return customerCache[customerId];
    }

    CustomerModel? customer = await customerService.getCustomerById(customerId);
    if (customer != null) {
      customerCache[customerId] = customer;
    }
    return customer;
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.error, color: Colors.red, size: 50),
          SizedBox(height: 8.0),
          Text(
            'Error loading tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.0),
          Text(
            'Please check your network connection or try again later.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info, color: Colors.blue, size: 50),
          const SizedBox(height: 8.0),
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'There are currently no measurement tasks to display.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCompletedTaskDetailsDialog(
      BuildContext context, TaskModel task, CustomerModel? customer) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Task Details: ${task.title}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${task.status}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8.0),
                Text('Measurement Date: ${task.measurementDate != null ? DateFormat('yyyy-MM-dd').format(task.measurementDate!.toDate()) : '-'}'),
                const SizedBox(height: 8.0),
                Text('Remarks: ${task.remarks ?? '-'}'),
                const SizedBox(height: 16.0),
                const Text(
                  'Customer Details:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                Text('Name: ${customer?.name ?? 'Unavailable'}'),
                Text('Email: ${customer?.email ?? 'Unavailable'}'),
                Text('Phone: ${customer?.phone ?? 'Unavailable'}'),
                Text('Address: ${customer?.address ?? 'Unavailable'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showTaskDetailsDialog(
      BuildContext context,
      TaskModel task,
      MeasurementService measurementService,
      EnquiryService enquiryService,
      CustomerService customerService) async {
    EnquiryModel? associatedEnquiry = await enquiryService.getEnquiryById(task.enquiryId);
    if (associatedEnquiry == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Associated enquiry not found.')),
        );
      }
      return;
    }

    String customerId = associatedEnquiry.customerId;
    CustomerModel? associatedCustomer = await customerService.getCustomerById(customerId);
    if (associatedCustomer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Associated customer not found.')),
        );
      }
      return;
    }

    // product now is product category
    String productCategory = associatedEnquiry.product;
    String specificProductScene = associatedEnquiry.specificProductScene;

    final parentContext = this.context;

    crNumberController.clear();
    remarksController.clear();
    tatController.clear();
    measurementDate = null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text('Complete Task: ${task.title}'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    // Display Customer Details
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Details:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: TextEditingController(text: associatedCustomer.name),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: TextEditingController(text: associatedCustomer.email),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: TextEditingController(text: associatedCustomer.address),
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: TextEditingController(text: associatedCustomer.phone),
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Display Product Category and Specific Product Scene
                    TextField(
                      controller: TextEditingController(text: productCategory),
                      decoration: const InputDecoration(
                        labelText: 'Product Category',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16.0),

                    TextField(
                      controller: TextEditingController(text: specificProductScene),
                      decoration: const InputDecoration(
                        labelText: 'Specific Product Scene',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16.0),

                    ElevatedButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: measurementDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          if (mounted) {
                            setStateDialog(() {
                              measurementDate = pickedDate;
                            });
                          }
                        }
                      },
                      child: Text(
                        measurementDate == null
                            ? 'Select Measurement Date'
                            : 'Measurement Date: ${DateFormat('yyyy-MM-dd').format(measurementDate!)}',
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                // Reject Task Button
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await measurementService.rejectTaskToFollowUp(taskId: task.taskId);
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Task rejected. Status reverted to Follow-up.')),
                        );
                        setState(() {});
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Error rejecting task. Please try again.')),
                        );
                      }
                    }
                  },
                  child: const Text('Reject Task', style: TextStyle(color: Colors.red)),
                ),

                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (measurementDate == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Please select a measurement date.')),
                        );
                      }
                      return;
                    }

                    try {
                      await measurementService.updateTaskAndEnquiryToMOK(
                        taskId: task.taskId,
                        product: productCategory,
                        crNumber: crNumberController.text,
                        measurementDate: measurementDate,
                        remarks: remarksController.text,
                        tat: int.tryParse(tatController.text) ?? 0,
                      );
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Task marked as completed (MOK)')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Error completing task. Please try again.')),
                        );
                      }
                    }
                  },
                  child: const Text('Complete Task'),
                ),
              ],
            );
          },
        );
      }
    );
  }

  @override
  void dispose() {
    crNumberController.dispose();
    remarksController.dispose();
    tatController.dispose();
    super.dispose();
  }
}
