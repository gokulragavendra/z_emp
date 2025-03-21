// lib/screens/sales_staff/sale_history_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class SaleHistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> historyDoc;

  const SaleHistoryDetailScreen({Key? key, required this.historyDoc})
      : super(key: key);

  @override
  State<SaleHistoryDetailScreen> createState() =>
      _SaleHistoryDetailScreenState();
}

class _SaleHistoryDetailScreenState extends State<SaleHistoryDetailScreen> {
  bool _isRefreshing = false;
  String _errorMessage = '';

  /// Simulated refresh operation, just waits briefly to show the loading indicator.
  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1)); // simulate loading
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  /// Shows a confirmation dialog with a given [title] and [message].
  /// Returns true if the user confirms; otherwise, false.
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

  @override
  Widget build(BuildContext context) {
    // We wrap everything in a try/catch to handle any missing or invalid data fields
    String customerName = 'Unknown';
    String phone = '';
    String productCategory = '';
    String dateStr = '--';
    String currentStatus = 'N/A';
    List statusHistory = [];
    dynamic orderValue;
    dynamic crNumber;
    String? tatDateStr;

    try {
      final doc = widget.historyDoc;
      customerName = doc['customerName'] ?? 'Unknown';
      phone = doc['phoneNumber'] ?? '';
      productCategory = doc['productCategory'] ?? '';
      final createdAtTs = doc['createdAt'] as Timestamp?;
      final createdAt = createdAtTs?.toDate();
      if (createdAt != null) {
        dateStr = DateFormat('yyyy-MM-dd').format(createdAt);
      }
      currentStatus = doc['currentStatus'] ?? 'N/A';
      statusHistory = doc['statusHistory'] ?? [];

      orderValue = doc['orderValue'];
      crNumber = doc['crNumber'];
      final tatDateTs = doc['tatDate'] as Timestamp?;
      if (tatDateTs != null) {
        tatDateStr = DateFormat('yyyy-MM-dd').format(tatDateTs.toDate());
      }
    } catch (e) {
      _errorMessage = 'Error parsing sale history data: $e';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale History Details'),
      ),
      // A Stack so we can overlay a loading indicator during the pull-to-refresh
      body: Stack(
        children: [
          // Pull-to-refresh on a SingleChildScrollView
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              // We ensure scroll always possible to trigger the refresh
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _buildContent(
                customerName: customerName,
                phone: phone,
                productCategory: productCategory,
                dateStr: dateStr,
                currentStatus: currentStatus,
                statusHistory: statusHistory,
                orderValue: orderValue,
                crNumber: crNumber,
                tatDateStr: tatDateStr,
              ),
            ),
          ),
          // In-case we had a parse error, show it in a SnackBar-like overlay
          if (_errorMessage.isNotEmpty)
            Center(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          // If refreshing, we overlay a semi-transparent spinner
          if (_isRefreshing)
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

  Widget _buildContent({
    required String customerName,
    required String phone,
    required String productCategory,
    required String dateStr,
    required String currentStatus,
    required List statusHistory,
    required dynamic orderValue,
    required dynamic crNumber,
    required String? tatDateStr,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Details Section
            Text(
              customerName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Tapping the phone number triggers a confirmation, then copies it to clipboard
            GestureDetector(
              onTap: () async {
                if (phone.isNotEmpty) {
                  final confirm = await _showConfirmationDialog(
                    'Copy Phone Number',
                    'Do you want to copy this phone number to the clipboard?',
                  );
                  if (confirm) {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone number copied: $phone')),
                      );
                    }
                  }
                }
              },
              child: Text(
                'Phone: $phone',
                style: const TextStyle(
                    fontSize: 16, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 4),
            Text('Product: $productCategory',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Created: $dateStr', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text(
              'Current Status: $currentStatus',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Extra (Additional) Details Section (if available)
            if (orderValue != null ||
                crNumber != null ||
                tatDateStr != null) ...[
              const Text(
                'Additional Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              if (orderValue != null)
                ListTile(
                  leading:
                      const Icon(Icons.monetization_on, color: Colors.orange),
                  title: Text('Order Value: $orderValue'),
                ),
              if (crNumber != null)
                ListTile(
                  leading: const Icon(Icons.confirmation_number,
                      color: Colors.deepPurple),
                  title: Text('CR Number: $crNumber'),
                ),
              if (tatDateStr != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: Text('Tat Date: $tatDateStr'),
                ),
              const SizedBox(height: 16),
            ],
            // Status History Section
            const Text(
              'Status History:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...statusHistory.map((entry) {
              final status = entry['status'] ?? '';
              final updatedAtTs = entry['updatedAt'] as Timestamp?;
              final updatedAt = updatedAtTs?.toDate();
              final updatedAtStr = updatedAt != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)
                  : '--';
              return ListTile(
                leading:
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                title: Text(status),
                subtitle: Text('Updated: $updatedAtStr'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
