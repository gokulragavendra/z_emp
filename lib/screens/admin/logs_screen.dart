import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/log_service.dart';
import '../../models/log_model.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late Future<List<LogModel>> _logsFuture; // Future for fetching logs
  bool _isLoading = false; // Indicates if a destructive action is in progress
  bool _isRefreshing = false; // Indicates if the user is pulling to refresh

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
  }

  /// Fetch logs from LogService with basic error handling.
  Future<List<LogModel>> _fetchLogs() async {
    final logService = Provider.of<LogService>(context, listen: false);
    try {
      return await logService.getLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching logs: $e')),
        );
      }
      rethrow; // Let the FutureBuilder also handle this
    }
  }

  /// Called when the user pulls down to refresh logs in the UI.
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      // Reassign the future so the FutureBuilder re-runs
      _logsFuture = _fetchLogs();
      // Wait for the future to finish so the RefreshIndicator can hide properly
      await _logsFuture;
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// If you had a destructive action like "Clear All Logs" that you actually used,
  /// you'd demonstrate it here. For now, we remove it because your LogService
  /// doesn't define such a method, and we want to avoid warnings.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'User Activity Logs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  // Wrap our list in a RefreshIndicator for pull-to-refresh
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: FutureBuilder<List<LogModel>>(
                      future: _logsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return const Center(
                            child: Text('Error fetching logs.'),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(child: Text('No logs found.'));
                        } else {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final log = snapshot.data![index];
                              return ListTile(
                                title: Text(log.userId),
                                subtitle: Text(
                                  'Action: ${log.action}'
                                  ' - Timestamp: ${log.timestamp.toDate()}',
                                ),
                                trailing: const Icon(Icons.info_outline),
                                onTap: () {
                                  // Show details of the log entry if needed.
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

          // If a destructive action or refresh is in progress, show a loading overlay
          if (_isLoading || _isRefreshing)
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
}
