import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sales_service.dart';
import '../../models/sales_model.dart';

class SalesOverviewScreen extends StatefulWidget {
  const SalesOverviewScreen({super.key});

  @override
  State<SalesOverviewScreen> createState() => _SalesOverviewScreenState();
}

class _SalesOverviewScreenState extends State<SalesOverviewScreen> {
  late Future<List<SalesModel>>
      _salesFuture; // Manages the future for sales data
  bool _isLoading =
      false; // For additional operations (if any) requiring a spinner

  @override
  void initState() {
    super.initState();
    _salesFuture = _fetchSales();
  }

  /// Fetch sales data with basic error handling.
  Future<List<SalesModel>> _fetchSales() async {
    final salesService = Provider.of<SalesService>(context, listen: false);
    try {
      return await salesService.getSales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching sales data: $e')),
        );
      }
      rethrow; // Let the FutureBuilder see the error
    }
  }

  /// Allows pull-to-refresh logic by reassigning the future.
  Future<void> _handleRefresh() async {
    // If you want to show an extra overlay spinner for refresh, toggle _isLoading here.
    // However, the built-in RefreshIndicator spinner usually suffices:
    _salesFuture = _fetchSales();
    // Wait for the new future to complete so the RefreshIndicator can hide properly.
    await _salesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Overview'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content with pull-to-refresh
          RefreshIndicator(
            onRefresh: _handleRefresh,
            child: FutureBuilder<List<SalesModel>>(
              future: _salesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error fetching sales data.'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No sales data found.'),
                  );
                }

                // We have a non-empty list of sales
                final sales = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Total Sales Overview',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16.0),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sales.length,
                          itemBuilder: (context, index) {
                            final sale = sales[index];
                            return ListTile(
                              title: Text(sale.productsSold.toString()),
                              subtitle: Text(
                                'Amount: \$${sale.crAmount.toStringAsFixed(2)}'
                                ' - Status: ${sale.salesStatus}',
                              ),
                              trailing: Text(sale.salesStatus),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // If an additional operation were in progress, we'd overlay a spinner
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
