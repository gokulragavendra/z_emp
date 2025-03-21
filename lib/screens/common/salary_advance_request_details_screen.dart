import 'package:flutter/material.dart';
import 'package:z_emp/models/salary_advance_model.dart';
import 'package:url_launcher/url_launcher.dart';

class SalaryAdvanceRequestDetailsScreen extends StatefulWidget {
  final SalaryAdvanceModel request;

  const SalaryAdvanceRequestDetailsScreen({super.key, required this.request});

  @override
  State<SalaryAdvanceRequestDetailsScreen> createState() =>
      _SalaryAdvanceRequestDetailsScreenState();
}

class _SalaryAdvanceRequestDetailsScreenState
    extends State<SalaryAdvanceRequestDetailsScreen> {
  bool _isLoading = false;

  Future<void> _launchURL(BuildContext context, String urlString) async {
    setState(() => _isLoading = true);
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      )) {
        _showSnackbar(context, 'Could not open attachment');
      }
    } catch (e) {
      _showSnackbar(context, 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildRequestDetails(context),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestDetails(BuildContext context) {
    return ListView(
      children: [
        _buildDetailTile(
            'Amount Requested',
            '₹${widget.request.amountRequested.toStringAsFixed(2)}',
            Icons.monetization_on),
        _buildDetailTile('Reason', widget.request.reason, Icons.comment),
        _buildDetailTile(
            'Repayment Option', widget.request.repaymentOption, Icons.receipt),
        if (widget.request.repaymentOption == 'Single Payment')
          _buildDetailTile('Repayment Month',
              widget.request.repaymentMonth ?? '', Icons.calendar_month),
        if (widget.request.repaymentOption == 'Part Payment')
          _buildDetailTile(
            'Repayment Period',
            '${widget.request.repaymentFromMonth} to ${widget.request.repaymentToMonth}',
            Icons.date_range,
          ),
        _buildDetailTile(
            'Date Submitted',
            widget.request.dateSubmitted
                .toDate()
                .toLocal()
                .toString()
                .split(' ')[0],
            Icons.today),
        if (widget.request.attachmentUrl.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.attach_file, color: Colors.indigo),
            title: const Text('Attachment'),
            subtitle: TextButton(
              onPressed: () =>
                  _launchURL(context, widget.request.attachmentUrl),
              child: const Text('Download/View Attachment'),
            ),
          ),
        if (widget.request.status != 'Pending')
          ListTile(
            leading:
                Icon(Icons.info, color: _getStatusColor(widget.request.status)),
            title: Text(
              'Status: ${widget.request.status}',
              style: TextStyle(
                  color: _getStatusColor(widget.request.status),
                  fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                'Processed By: ${widget.request.approvedBy}\non ${widget.request.approvalDate?.toDate().toLocal().toString().split(' ')[0]}'),
          ),
      ],
    );
  }

  Widget _buildDetailTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Colors.blue;
    }
  }
}
