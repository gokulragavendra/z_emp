import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/enquiry_service.dart';
import '../../services/follow_up_service.dart';
import '../../models/enquiry_model.dart';
import '../../models/follow_up_model.dart';

class EnquiryManagementScreen extends StatefulWidget {
  const EnquiryManagementScreen({Key? key}) : super(key: key);

  @override
  _EnquiryManagementScreenState createState() =>
      _EnquiryManagementScreenState();
}

class _EnquiryManagementScreenState extends State<EnquiryManagementScreen> {
  // Search and filter fields
  String searchQuery = '';
  String selectedStatus = 'All';
  final List<String> statusOptions = [
    'All',
    'Enquiry',
    'Follow-up',
    'MTBT',
    'MOK',
    'Sale done'
  ];

  // Manages the future returned by getEnquiries()
  late Future<List<EnquiryModel>> _enquiryFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Load enquiries initially
    _enquiryFuture = _loadEnquiries();
  }

  /// Loads enquiries from the EnquiryService.
  Future<List<EnquiryModel>> _loadEnquiries() async {
    final enquiryService = Provider.of<EnquiryService>(context, listen: false);
    try {
      final data = await enquiryService.getEnquiries();
      return data;
    } catch (e) {
      // If we want to show a SnackBar on error:
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching enquiries: $e')),
        );
      }
      rethrow; // Re-throw for the FutureBuilder to catch
    }
  }

  /// Handles pull-to-refresh logic by re-running _loadEnquiries().
  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
      // Reassign the future so the FutureBuilder re-runs
      _enquiryFuture = _loadEnquiries();
    });
    // Wait for the future to complete before removing the refresh indicator
    try {
      await _enquiryFuture;
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final followUpService =
        Provider.of<FollowUpService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiry Management'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            _buildSearchFilterSection(),
            Expanded(
              // Wrap the main list in a RefreshIndicator
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                // Use a FutureBuilder to render enquiries
                child: FutureBuilder<List<EnquiryModel>>(
                  future: _enquiryFuture,
                  builder: (context, snapshot) {
                    // While waiting
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // If an error occurred
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error fetching enquiries.',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    // If no data or empty
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No enquiries found.'),
                      );
                    }

                    // Filter the enquiries based on search query and status
                    final allEnquiries = snapshot.data!;
                    final filteredEnquiries = allEnquiries.where((enquiry) {
                      final matchesQuery = searchQuery.isEmpty ||
                          enquiry.customerName
                              .toLowerCase()
                              .contains(searchQuery.toLowerCase()) ||
                          enquiry.phoneNumber.contains(searchQuery);

                      final matchesStatus = (selectedStatus == 'All') ||
                          (enquiry.status == selectedStatus);

                      return matchesQuery && matchesStatus;
                    }).toList();

                    if (filteredEnquiries.isEmpty) {
                      return const Center(
                        child: Text('No enquiries match your search.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filteredEnquiries.length,
                      itemBuilder: (context, index) {
                        final enquiry = filteredEnquiries[index];
                        return _buildEnquiryCard(enquiry, followUpService);
                      },
                    );
                  },
                ),
              ),
            ),
            // Show a small indicator if user is still refreshing
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by Name or Phone',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (query) {
                  setState(() {
                    searchQuery = query;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: statusOptions
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value ?? 'All';
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Filter by Status',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnquiryCard(
    EnquiryModel enquiry,
    FollowUpService followUpService,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        title: Text(
          enquiry.customerName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Product: ${enquiry.product}  •  Status: ${enquiry.status}',
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
        trailing: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
        children: [
          _buildFollowUpSection(enquiry, followUpService),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EnquiryDetailScreen(enquiry: enquiry),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('View Full Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection(
    EnquiryModel enquiry,
    FollowUpService followUpService,
  ) {
    return FutureBuilder<List<FollowUpModel>>(
      future: followUpService.getFollowUpsByEnquiry(enquiry.enquiryId),
      builder: (context, snapshot) {
        // While waiting for data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // If error
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Error loading follow-ups: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        // If no data
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No follow-ups recorded for this enquiry.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          );
        }

        final followUps = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-Up History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...followUps.map((followUp) {
              final formattedDate =
                  DateFormat('yyyy-MM-dd').format(followUp.callDate.toDate());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      color: followUp.isPositive ? Colors.green : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$formattedDate: ${followUp.callResponse}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class EnquiryDetailScreen extends StatelessWidget {
  final EnquiryModel enquiry;
  const EnquiryDetailScreen({super.key, required this.enquiry});

  @override
  Widget build(BuildContext context) {
    final followUpService =
        Provider.of<FollowUpService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiry Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDetailRow('Enquiry Name', enquiry.enquiryName),
            _buildDetailRow('Customer Name', enquiry.customerName),
            _buildDetailRow('Phone', enquiry.phoneNumber),
            _buildDetailRow('Product', enquiry.product),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Follow-Up History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildFollowUpHistory(context, followUpService, enquiry.enquiryId),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpHistory(
    BuildContext context,
    FollowUpService followUpService,
    String enquiryId,
  ) {
    return FutureBuilder<List<FollowUpModel>>(
      future: followUpService.getFollowUpsByEnquiry(enquiryId),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // Error
        if (snapshot.hasError) {
          return const Text('Error fetching follow-ups.');
        }
        // Empty or no data
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No follow-ups recorded.');
        }

        final followUps = snapshot.data!;
        return Column(
          children: followUps.map((followUp) {
            final formattedDate =
                DateFormat('yyyy-MM-dd').format(followUp.callDate.toDate());
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.circle,
                  color: followUp.isPositive ? Colors.green : Colors.red,
                  size: 12,
                ),
                title: Text('Date: $formattedDate'),
                subtitle: Text('Response: ${followUp.callResponse}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
