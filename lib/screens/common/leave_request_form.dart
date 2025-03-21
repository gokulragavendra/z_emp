import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../services/leave_request_service.dart';
import '../../models/leave_request_model.dart';

class LeaveRequestForm extends StatefulWidget {
  const LeaveRequestForm({super.key});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm>
    with SingleTickerProviderStateMixin {
  final TextEditingController reasonController = TextEditingController();
  String leaveType = 'Sick Leave';
  String dayType = 'Full Day';
  DateTime? startDate;
  DateTime? endDate;
  String? userName;

  late TabController _tabController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          dayType = _tabController.index == 0 ? 'Full Day' : 'Half Day';
        });
      }
    });
  }

  @override
  void dispose() {
    reasonController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (!mounted) return;
        setState(() {
          userName = userDoc['name'] ?? 'User';
        });
      } catch (e) {
        setState(() {
          userName = 'User';
        });
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          startDate = pickedDate;
        } else {
          endDate = pickedDate;
        }
      });
    }
  }

  Future<bool> _validateAndSubmit(
      LeaveRequestService leaveRequestService, String userId) async {
    if (startDate == null || (dayType == 'Full Day' && endDate == null)) {
      _showError('Please select appropriate dates.');
      return false;
    }
    if (dayType == 'Full Day' && endDate!.isBefore(startDate!)) {
      _showError('End date must be after start date.');
      return false;
    }
    if (reasonController.text.trim().isEmpty) {
      _showError('Please provide a reason for leave.');
      return false;
    }

    bool? confirm = await _showConfirmationDialog();
    if (confirm == false) return false;

    setState(() => _isSubmitting = true);
    try {
      await leaveRequestService.submitLeaveRequest(
        userId: userId,
        name: userName ?? 'User',
        leaveType: leaveType,
        startDate: Timestamp.fromDate(startDate!),
        endDate: dayType == 'Full Day'
            ? Timestamp.fromDate(endDate!)
            : Timestamp.fromDate(startDate!),
        dayType: dayType,
        reason: reasonController.text.trim(),
      );
      setState(() {
        reasonController.clear();
        startDate = null;
        endDate = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted successfully.')),
      );
      return true;
    } catch (e) {
      _showError('Failed to submit leave request: $e');
      return false;
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool?> _showConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content:
            const Text('Are you sure you want to submit this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to request leave.')));
    }
    final leaveRequestService =
        Provider.of<LeaveRequestService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Request')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField(
                  value: leaveType,
                  items: const [
                    DropdownMenuItem(
                        value: 'Sick Leave', child: Text('Sick Leave')),
                    DropdownMenuItem(
                        value: 'Personal Leave', child: Text('Personal Leave')),
                  ],
                  onChanged: (value) => setState(() => leaveType = value!),
                ),
                const SizedBox(height: 10),
                _buildDateSelector(
                    'Start Date', startDate, () => _pickDate(isStart: true)),
                if (dayType == 'Full Day')
                  _buildDateSelector(
                      'End Date', endDate, () => _pickDate(isStart: false)),
                TextField(
                    controller: reasonController,
                    decoration:
                        const InputDecoration(hintText: 'Enter Reason')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      _validateAndSubmit(leaveRequestService, currentUser.uid),
                  child: const Text('Submit Leave Request'),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
          date == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(date)),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }
}
