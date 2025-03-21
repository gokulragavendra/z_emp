// lib/screens/sales_staff/customer_search_delegate.dart

import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
// Adjust the import path as needed

class CustomerSearchDelegate extends SearchDelegate<CustomerModel?> {
  final List<CustomerModel> customers;
  final Function(CustomerModel) onSelected;

  CustomerSearchDelegate({
    required this.customers,
    required this.onSelected,
  });

  @override
  String get searchFieldLabel => 'Search Customers';

  @override
  TextStyle get searchFieldStyle => const TextStyle(fontSize: 16);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  /// Wrap the filtering logic in an async method to allow a loading icon and error handling.
  Future<List<CustomerModel>> _searchCustomers(String q) async {
    // Artificial delay so the loading indicator can appear; adjust or remove as desired.
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      final lowerQuery = q.toLowerCase();
      // This is your original filter logic, unchanged:
      final filtered = customers.where((customer) {
        return customer.name.toLowerCase().contains(lowerQuery) ||
            customer.phone.toLowerCase().contains(lowerQuery) ||
            customer.email.toLowerCase().contains(lowerQuery) ||
            customer.address.toLowerCase().contains(lowerQuery);
      }).toList();

      return filtered;
    } catch (e) {
      throw Exception('Error while searching: $e');
    }
  }

  /// Optional confirmation dialog before finalizing the customer's selection.
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

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<CustomerModel>>(
      future: _searchCustomers(query),
      builder: (context, snapshot) {
        // 1) Show a loading icon while the async search runs.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // 2) Display any error that occurred, plus a Retry button.
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('An error occurred: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Just call setState() to rebuild and retry the future
                    // The FutureBuilder will run again with the same query
                    buildResults(context);
                    // Alternatively: setState(() {});
                    // but "buildResults(context)" is enough to re-trigger a re-build.
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        // 3) Return the filtered results if no error.
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No customers found.'));
        }
        return _buildCustomerList(context, results);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<List<CustomerModel>>(
      future: _searchCustomers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('An error occurred: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Rebuild to retry
                    buildSuggestions(context);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) {
          return const Center(child: Text('No customers found.'));
        }
        return _buildCustomerList(context, suggestions);
      },
    );
  }

  Widget _buildCustomerList(
      BuildContext context, List<CustomerModel> customerList) {
    // This logic is exactly as you had it, unaltered, just extracted into a method
    // so both suggestions and results can use it consistently.
    return ListView.builder(
      itemCount: customerList.length,
      itemBuilder: (context, index) {
        final customer = customerList[index];
        return ListTile(
          title: Text(customer.name),
          subtitle: Text('Phone: ${customer.phone}\nEmail: ${customer.email}'),
          onTap: () async {
            // Optional confirmation step. If you don't want it, you can remove these lines.
            final confirmed = await _showConfirmationDialog(
              context,
              'Select Customer',
              'Are you sure you want to select ${customer.name}?',
            );
            if (confirmed) {
              onSelected(customer);
              close(context, customer);
            }
          },
        );
      },
    );
  }
}
