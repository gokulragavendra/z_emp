import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/leave_management_service.dart';
import '../../models/leave_request_model.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  DateTime? selectedDate;

  // Indicates when an approve/reject action is happening
  bool _isProcessingAction = false;

  // Indicates a manual pull-to-refresh or data reload
  bool _isRefreshing = false;

  /// Refreshes requests by re-building the widget or re-fetching them from the service.
  Future<void> _refreshRequests() async {
    setState(() => _isRefreshing = true);
    try {
      // If your service has a method to force refresh, call it here.
      // For now, we just re-build the UI.
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing requests: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Confirmation dialog for destructive actions like "Reject" or "Approve."
  Future<bool> _confirmAction(String actionName) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text('Confirm $actionName'),
              content:
                  Text('Are you sure you want to $actionName this request?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(actionName),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final leaveManagementService =
        Provider.of<LeaveManagementService>(context, listen: false);

    // Calculate an adaptive height for the pending requests section
    final pendingSectionHeight = MediaQuery.of(context).size.height * 0.30;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          Container(
            // Gradient background
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Pending leave requests displayed horizontally
                  _buildPendingRequestsSection(
                    leaveManagementService,
                    pendingSectionHeight,
                  ),
                  const SizedBox(height: 24.0),
                  // Leave history
                  _buildLeaveHistorySection(leaveManagementService),
                ],
              ),
            ),
          ),

          // Overlays a loading indicator if an approve/reject action or refresh is in progress
          if (_isProcessingAction || _isRefreshing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Pending Requests Section (Adaptive Height)
  // ----------------------------------------------------
  Widget _buildPendingRequestsSection(
    LeaveManagementService service,
    double height,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Leave Requests',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          height: height,
          child: RefreshIndicator(
            onRefresh: _refreshRequests,
            child: FutureBuilder<List<LeaveRequestModel>>(
              future: service.getPendingLeaveRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No pending leave requests.'),
                  );
                }

                final requests = snapshot.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _buildPendingRequestCard(requests[index], service);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestCard(
    LeaveRequestModel request,
    LeaveManagementService service,
  ) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16.0),
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          // Reduced vertical padding to avoid overflow
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User name and leave type
              Text(
                'User: ${request.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info, color: Colors.deepPurple, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${request.leaveType} (${request.dayType})',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Dates
              Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.teal, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${DateFormat('yyyy-MM-dd').format(request.startDate.toDate())} '
                      'to ${DateFormat('yyyy-MM-dd').format(request.endDate.toDate())}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Reason
              Text(
                'Reason: ${request.reason}',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Status
              Text(
                'Status: ${request.status}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  // If "Approved," text is green; if "Rejected," text is red; else orange
                  color: request.status.toLowerCase() == 'approved'
                      ? Colors.green
                      : request.status.toLowerCase() == 'rejected'
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              // Approved By
              Text(
                'Approved By: ${request.approvedBy ?? 'N/A'}',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final confirmed = await _confirmAction('Approve');
                      if (!confirmed) return;

                      setState(() => _isProcessingAction = true);
                      try {
                        await service.updateLeaveRequestStatus(
                          request.leaveId,
                          'Approved',
                        );
                        if (!mounted) return;
                        await _refreshRequests();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error approving request: $e'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessingAction = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child:
                        const Text('Approve', style: TextStyle(fontSize: 14)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final confirmed = await _confirmAction('Reject');
                      if (!confirmed) return;

                      setState(() => _isProcessingAction = true);
                      try {
                        await service.updateLeaveRequestStatus(
                          request.leaveId,
                          'Rejected',
                        );
                        if (!mounted) return;
                        await _refreshRequests();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error rejecting request: $e'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessingAction = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Reject', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Leave History Section
  // ----------------------------------------------------
  Widget _buildLeaveHistorySection(LeaveManagementService service) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave History',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Date selection tile
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            tileColor: Colors.white,
            title: Text(
              selectedDate == null
                  ? 'Tap to Select a Date'
                  : 'Selected Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
              style: TextStyle(
                color: selectedDate == null ? Colors.grey : Colors.black87,
                fontSize: 16,
              ),
            ),
            trailing:
                const Icon(Icons.calendar_today, color: Colors.deepPurple),
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null && mounted) {
                setState(() => selectedDate = pickedDate);
              }
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FutureBuilder<List<LeaveRequestModel>>(
                future: service.getLeaveRequestsForDate(selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No leave history for selected date.'),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(12.0),
                    children: snapshot.data!
                        .map((leave) => _buildHistoryListTile(leave))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryListTile(LeaveRequestModel leave) {
    final start = DateFormat('yyyy-MM-dd').format(leave.startDate.toDate());
    final end = DateFormat('yyyy-MM-dd').format(leave.endDate.toDate());
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Text(
          'User: ${leave.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            'Leave Type: ${leave.leaveType} (${leave.dayType})\n'
            'From: $start to $end\n'
            'Status: ${leave.status}\n'
            'Reason: ${leave.reason}\n'
            'Approved By: ${leave.approvedBy ?? 'N/A'}',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
