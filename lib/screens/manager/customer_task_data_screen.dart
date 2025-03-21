// lib/screens/manager/customer_task_data_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/enquiry_service.dart';
import '../../models/enquiry_model.dart';

class CustomerTaskDataScreen extends StatefulWidget {
  const CustomerTaskDataScreen({Key? key}) : super(key: key);

  @override
  State<CustomerTaskDataScreen> createState() => _CustomerTaskDataScreenState();
}

class _CustomerTaskDataScreenState extends State<CustomerTaskDataScreen> {
  late Future<List<EnquiryModel>> _futureEnquiries;

  @override
  void initState() {
    super.initState();
    _futureEnquiries = _fetchEnquiries();
  }

  /// Retrieves the enquiries from the service
  Future<List<EnquiryModel>> _fetchEnquiries() {
    final enquiryService = Provider.of<EnquiryService>(context, listen: false);
    return enquiryService.getEnquiries();
  }

  /// Shows a simple confirmation dialog with the given [title] and [message].
  /// Returns true if "Yes" is pressed; otherwise returns false.
  Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
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

  /// Forces a reload of the enquiries. Used by the pull-to-refresh and anywhere else needed.
  Future<void> _refreshEnquiries() async {
    setState(() {
      _futureEnquiries = _fetchEnquiries();
    });
    // Give a moment to show the refresh indicator if needed
    await _futureEnquiries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer & Task Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Enquiries & Follow-Ups',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),

            // Expanded area with future builder wrapped in a RefreshIndicator
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshEnquiries,
                child: FutureBuilder<List<EnquiryModel>>(
                  future: _futureEnquiries,
                  builder: (context, snapshot) {
                    // Show loading spinner while awaiting data
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Show detailed error message on failure
                    else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error fetching enquiries: ${snapshot.error}',
                        ),
                      );
                    }
                    // Handle empty results
                    else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No enquiries found.'));
                    } else {
                      // We have data; build the list
                      final enquiries = snapshot.data!;
                      return ListView.builder(
                        itemCount: enquiries.length,
                        itemBuilder: (context, index) {
                          final enquiry = enquiries[index];
                          return ListTile(
                            title: Text(enquiry.enquiryName),
                            subtitle:
                                Text('Follow-Up Status: ${enquiry.status}'),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () async {
                              // Optional: ask for confirmation before proceeding
                              final confirm = await _showConfirmationDialog(
                                context,
                                'Open Enquiry',
                                'Open details for "${enquiry.enquiryName}"?',
                              );
                              if (confirm) {
                                // Navigate to enquiry details if needed
                                // Example:
                                // Navigator.push(...);
                              }
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
