// lib/screens/sales_staff/enquiry_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/enquiry_service.dart';
import '../../services/follow_up_service.dart';
import '../../services/user_service.dart';
import '../../models/enquiry_model.dart';
import '../../models/follow_up_model.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';

class EnquiryListScreen extends StatefulWidget {
  const EnquiryListScreen({Key? key}) : super(key: key);

  @override
  _EnquiryListScreenState createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends State<EnquiryListScreen> {
  String searchQuery = '';

  // Holds our future so we can refresh if desired
  late Future<List<EnquiryModel>> _futureEnquiries;

  // Displays an overlay loading indicator for time-consuming tasks (e.g., updating status)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize the Future when the screen first loads
    _futureEnquiries = _fetchEnquiries();
  }

  /// Helper to retrieve the current user's enquiries
  Future<List<EnquiryModel>> _fetchEnquiries() async {
    final enquiryService = Provider.of<EnquiryService>(context, listen: false);
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    try {
      final userId = currentUser?.userId ?? '';
      return await enquiryService.getEnquiriesByUserId(userId);
    } catch (e) {
      throw Exception('Failed to load enquiries: $e');
    }
  }

  /// Pull-to-refresh: re-run the future so the FutureBuilder reloads
  Future<void> _refreshEnquiries() async {
    setState(() {
      _futureEnquiries = _fetchEnquiries();
    });
    await _futureEnquiries; // Wait for the future to complete
  }

  /// Toggles the loading overlay
  void _setLoading(bool value) {
    if (mounted) {
      setState(() {
        _isLoading = value;
      });
    }
  }

  /// Optional confirmation dialog
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enquiry List')),
      // Use a Stack to display an overlay loading spinner
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Enquiries',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Enquiries',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) {
                    if (!mounted) return;
                    setState(() {
                      searchQuery = query;
                    });
                  },
                ),
                const SizedBox(height: 16.0),

                // Wrap the FutureBuilder in a RefreshIndicator for pull-to-refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshEnquiries,
                    child: FutureBuilder<List<EnquiryModel>>(
                      future: _futureEnquiries,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Center(
                            child: Text('Error retrieving enquiries.'),
                          );
                        }
                        final allEnquiries = snapshot.data!;
                        final enquiries = allEnquiries
                            .where(
                              (enquiry) => enquiry.customerName
                                  .toLowerCase()
                                  .contains(searchQuery.toLowerCase()),
                            )
                            .toList();

                        if (enquiries.isEmpty) {
                          return const Center(
                              child: Text('No enquiries found.'));
                        }

                        // Same list-building code as before
                        return ListView.builder(
                          itemCount: enquiries.length,
                          itemBuilder: (context, index) {
                            final enquiry = enquiries[index];
                            return ListTile(
                              title: Text(enquiry.customerName),
                              subtitle: Text('Status: ${enquiry.status}'),
                              trailing: Text(
                                DateFormat('yyyy-MM-dd')
                                    .format(enquiry.enquiryDate.toDate()),
                              ),
                              onTap: () => _showEnquiryDetails(enquiry),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // The loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // New helper: Show a popup for extra data (Order Value, CR Number, Tat Date)
  // No changes made; we simply keep your existing functionality as is.
  Future<Map<String, Object>?> _showExtraDataPopup() async {
    final orderValueController = TextEditingController();
    final crNumberController = TextEditingController();
    DateTime? tatDate;
    final formKey = GlobalKey<FormState>();

    return await showDialog<Map<String, Object>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Enter Additional Details'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: orderValueController,
                        decoration: const InputDecoration(
                          labelText: 'Order Value',
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: crNumberController,
                        decoration: const InputDecoration(
                          labelText: 'CR Number',
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: tatDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setStateDialog(() {
                              tatDate = pickedDate;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: tatDate == null
                                  ? 'Select Tat Date'
                                  : 'Tat Date: ${DateFormat('yyyy-MM-dd').format(tatDate!)}',
                            ),
                            validator: (value) {
                              if (tatDate == null) return 'Required';
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate() && tatDate != null) {
                      Navigator.pop(dialogContext, {
                        'orderValue': orderValueController.text.trim(),
                        'crNumber': crNumberController.text.trim(),
                        'tatDate': Timestamp.fromDate(tatDate!),
                      });
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // Wraps your original logic in a try/catch and an optional confirmation
  void _showEnquiryDetails(EnquiryModel enquiry) async {
    final followUpService =
        Provider.of<FollowUpService>(context, listen: false);
    final enquiryService = Provider.of<EnquiryService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    String newStatus = enquiry.status;
    String? selectedMeasurementStaff;
    bool statusDisabled = false;

    // Determine allowed status transitions based on current status
    List<String> allowedStatuses = [];
    switch (enquiry.status) {
      case 'Enquiry':
        allowedStatuses = ['Enquiry', 'Follow-up'];
        break;
      case 'Follow-up':
        allowedStatuses = ['Follow-up', 'MTBT'];
        break;
      case 'MTBT':
        allowedStatuses = ['MTBT'];
        statusDisabled = true;
        break;
      case 'MOK':
        allowedStatuses = ['MOK', 'Sale done'];
        break;
      case 'Sale done':
        allowedStatuses = ['Sale done'];
        statusDisabled = true;
        break;
      default:
        allowedStatuses = [enquiry.status];
        break;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<List<UserModel>> measurementStaffFuture =
                userService.getUsersByRole('Measurement Staff');

            return AlertDialog(
              scrollable: true,
              title: const Text('Enquiry Details'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Name: ${enquiry.customerName}'),
                  Text('Phone: ${enquiry.phoneNumber}'),
                  Text('Product Category: ${enquiry.product}'),
                  Text(
                      'Specific Product Scene: ${enquiry.specificProductScene}'),
                  Text('Current Status: ${enquiry.status}'),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    value: newStatus,
                    items: allowedStatuses
                        .map((statusOption) => DropdownMenuItem(
                              value: statusOption,
                              child: Text(statusOption),
                            ))
                        .toList(),
                    onChanged: statusDisabled
                        ? null
                        : (value) {
                            if (value != null) {
                              setStateDialog(() {
                                newStatus = value;
                              });
                            }
                          },
                    decoration: const InputDecoration(
                      labelText: 'Update Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  if (newStatus == 'MTBT')
                    FutureBuilder<List<UserModel>>(
                      future: measurementStaffFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError || !snapshot.hasData) {
                          return const Text('Error loading measurement staff');
                        } else {
                          return DropdownButtonFormField<String>(
                            value: selectedMeasurementStaff,
                            items: snapshot.data!
                                .map((user) => DropdownMenuItem(
                                      value: user.userId,
                                      child: Text(user.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setStateDialog(() {
                                selectedMeasurementStaff = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Assign Measurement Staff',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please select measurement staff'
                                : null,
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Follow-Ups',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  FutureBuilder<List<FollowUpModel>>(
                    future: followUpService
                        .getFollowUpsByEnquiry(enquiry.enquiryId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Text('Error loading follow-ups.');
                      }
                      final followUps = snapshot.data!;

                      if (followUps.isEmpty) {
                        return const Text('No follow-ups found.');
                      }

                      return Column(
                        children: followUps.map((followUp) {
                          return ListTile(
                            title: Text(
                              'Date: ${DateFormat('yyyy-MM-dd').format(followUp.callDate.toDate())}',
                            ),
                            subtitle:
                                Text('Response: ${followUp.callResponse}'),
                            trailing: Text(
                                followUp.isPositive ? 'Positive' : 'Negative'),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () => _addFollowUp(enquiry.enquiryId),
                    child: const Text('Add Follow-Up'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: statusDisabled
                      ? null
                      : () async {
                          // Confirm with user before updating
                          final confirmUpdate = await _showConfirmationDialog(
                            'Update Status',
                            'Are you sure you want to change status to $newStatus?',
                          );
                          if (!confirmUpdate) return;

                          // Now proceed with update
                          Navigator.pop(dialogContext);
                          _setLoading(true);
                          try {
                            // For Sale done, require extra data.
                            if (newStatus == 'Sale done') {
                              final extraData = await _showExtraDataPopup();
                              if (extraData != null) {
                                // Only update if extra data provided.
                                await enquiryService.updateEnquiryStatus(
                                  enquiry.enquiryId,
                                  newStatus,
                                );
                                await enquiryService
                                    .copyEnquiryToSalesHistoryWithExtraData(
                                  enquiry,
                                  extraData,
                                );
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Additional details not provided. Status remains unchanged.'),
                                    ),
                                  );
                                }
                              }
                            } else {
                              await enquiryService.updateEnquiryStatus(
                                enquiry.enquiryId,
                                newStatus,
                              );
                              // Fixed the "String?" to "String" by using selectedMeasurementStaff!
                              if (newStatus == 'MTBT' &&
                                  selectedMeasurementStaff != null) {
                                await enquiryService.assignMeasurementTask(
                                  enquiryId: enquiry.enquiryId,
                                  measurementStaffId: selectedMeasurementStaff!,
                                );
                              }
                            }
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Enquiry status updated successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            // Enhanced error handling
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error updating status: $e')),
                              );
                            }
                          } finally {
                            _setLoading(false);
                          }
                        },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Your original follow-up flow remains intact; we simply added a little error handling above.
  void _addFollowUp(String enquiryId) {
    final callResponseController = TextEditingController();
    bool isPositiveResponse = true;
    DateTime? callDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              scrollable: true,
              title: const Text('Add Follow-Up'),
              content: Column(
                children: [
                  TextFormField(
                    controller: callResponseController,
                    decoration: const InputDecoration(
                      labelText: 'Call Response',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: callDate != null
                          ? 'Call Date: ${DateFormat('yyyy-MM-dd').format(callDate!)}'
                          : 'Select Call Date',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: callDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        if (!mounted) return;
                        setStateDialog(() {
                          callDate = pickedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      const Text('Response: '),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Positive'),
                          value: true,
                          groupValue: isPositiveResponse,
                          onChanged: (value) {
                            if (!mounted) return;
                            setStateDialog(() {
                              isPositiveResponse = value ?? true;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Negative'),
                          value: false,
                          groupValue: isPositiveResponse,
                          onChanged: (value) {
                            if (!mounted) return;
                            setStateDialog(() {
                              isPositiveResponse = value ?? false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (callResponseController.text.isNotEmpty &&
                        callDate != null) {
                      final followUpService =
                          Provider.of<FollowUpService>(context, listen: false);
                      final newFollowUp = FollowUpModel(
                        followUpId: FirebaseFirestore.instance
                            .collection('followUps')
                            .doc()
                            .id,
                        enquiryId: enquiryId,
                        callDate: Timestamp.fromDate(callDate!),
                        callResponse: callResponseController.text,
                        isPositive: isPositiveResponse,
                      );
                      await followUpService.addFollowUp(newFollowUp);
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Follow-up added successfully')),
                      );
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
