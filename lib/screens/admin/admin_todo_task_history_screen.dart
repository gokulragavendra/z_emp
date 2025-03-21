// lib/screens/admin/admin_todo_task_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/todo_task_service.dart';
import '../../models/todo_task_model.dart';
// Import your localization
import '../../l10n/app_localizations.dart';

class AdminTodoTaskHistoryScreen extends StatefulWidget {
  const AdminTodoTaskHistoryScreen({super.key});

  @override
  State<AdminTodoTaskHistoryScreen> createState() =>
      _AdminTodoTaskHistoryScreenState();
}

class _AdminTodoTaskHistoryScreenState
    extends State<AdminTodoTaskHistoryScreen> {
  String searchQuery = '';
  String sortBy = 'createdAt';
  bool descending = true;

  bool _isLoading = false; // for manual loading indicator if needed

  /// Example of a manual fetch in case you want to do something custom
  Future<void> _manualFetch() async {
    setState(() => _isLoading = true);
    try {
      // do your data fetch here
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      final localization = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate("error") + ": $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final todoTaskService =
        Provider.of<TodoTaskService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text(localization.translate("tasks"))),
      body: Stack(
        children: [
          // Background gradient or color
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: _manualFetch, // or any other function you want
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [
                    // Search & sort UI
                    _buildSearchAndSort(localization),
                    const SizedBox(height: 16),
                    // Example list of tasks
                    Expanded(
                      child: StreamBuilder<List<TodoTaskModel>>(
                        stream: todoTaskService.getAllTasks(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Text(localization
                                  .translate("loading_please_wait")),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Center(
                              child: Text(localization.translate("error")),
                            );
                          }
                          List<TodoTaskModel> tasks = snapshot.data!;
                          // Only show Completed tasks
                          tasks = tasks
                              .where((task) => task.status == 'Completed')
                              .toList();

                          // Filter by search
                          if (searchQuery.isNotEmpty) {
                            tasks = tasks
                                .where((task) =>
                                    task.title
                                        .toLowerCase()
                                        .contains(searchQuery.toLowerCase()) ||
                                    task.description
                                        .toLowerCase()
                                        .contains(searchQuery.toLowerCase()))
                                .toList();
                          }

                          // Sort
                          tasks.sort((a, b) {
                            int cmp;
                            if (sortBy == 'createdAt') {
                              cmp = a.createdAt.compareTo(b.createdAt);
                            } else {
                              cmp = a.title.compareTo(b.title);
                            }
                            return descending ? -cmp : cmp;
                          });

                          if (tasks.isEmpty) {
                            return Center(
                              child:
                                  Text(localization.translate("no_data_found")),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                                child: ListTile(
                                  title: Text(task.title),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${localization.translate("task_description")}: ${task.description}',
                                      ),
                                      Text(
                                        'Completed on: ${DateFormat('yyyy-MM-dd').format(task.updatedAt.toDate())}',
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    DateFormat('yyyy-MM-dd')
                                        .format(task.createdAt.toDate()),
                                  ),
                                  onTap: () {
                                    // navigate to detail
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            _CompletedTaskDetailScreen(
                                          task: task,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _buildSearchAndSort(AppLocalizations localization) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              labelText: localization.translate("search"),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 16),
        DropdownButton<String>(
          value: sortBy,
          items: [
            DropdownMenuItem(
              value: 'createdAt',
              child: Text(localization.translate("select_date")),
            ),
            DropdownMenuItem(
              value: 'title',
              child: Text(localization.translate("task_title")),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => sortBy = value);
            }
          },
        ),
        IconButton(
          icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: () => setState(() => descending = !descending),
        ),
      ],
    );
  }
}

class _CompletedTaskDetailScreen extends StatelessWidget {
  final TodoTaskModel task;

  const _CompletedTaskDetailScreen({required this.task});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${localization.translate("task_details")}: ${task.title}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localization.translate("task_description")}: ${task.description}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localization.translate("task_status")}: ${task.status}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localization.translate("task_due_date")}: ${task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!.toDate()) : 'N/A'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localization.translate("createdAt") ?? 'Created At'}: ${DateFormat('yyyy-MM-dd').format(task.createdAt.toDate())}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                // Example of showing update history or additional details
                const Text(
                  'Update History:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                if (task.updateHistory == null || task.updateHistory!.isEmpty)
                  Text(localization.translate("no_data_found")),
                if (task.updateHistory != null)
                  ...task.updateHistory!.map((update) {
                    final ts = update['updatedAt'] as Timestamp?;
                    final updatedAtStr = ts != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                        : '--';
                    return ListTile(
                      title: Text(update['status'] ?? ''),
                      subtitle: Text(
                          '${localization.translate("task_description")}: ${update['progressDescription'] ?? ''}'),
                      trailing: Text('$updatedAtStr'),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
