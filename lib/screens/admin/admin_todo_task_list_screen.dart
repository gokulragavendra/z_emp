// lib/screens/admin/admin_todo_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/todo_task_service.dart';
import '../../services/user_service.dart';
import '../../models/todo_task_model.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';

class AdminTodoTaskListScreen extends StatefulWidget {
  const AdminTodoTaskListScreen({super.key});

  @override
  State<AdminTodoTaskListScreen> createState() =>
      _AdminTodoTaskListScreenState();
}

class _AdminTodoTaskListScreenState extends State<AdminTodoTaskListScreen> {
  String searchQuery = '';
  String filterStatus = 'All';
  List<String> statusOptions = ['All', 'Assigned', 'Accepted', 'In Progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final todoTaskService = Provider.of<TodoTaskService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('All Todo Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Todo Task List',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),

            // Search and Filter
            Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Tasks',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                // Status Filter Dropdown
                DropdownButton<String>(
                  value: filterStatus,
                  items: statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        filterStatus = value;
                      });
                    }
                  },
                  hint: const Text('Filter by Status'),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Todo Task List
            Expanded(
              child: StreamBuilder<List<TodoTaskModel>>(
                stream: todoTaskService.getAllTasks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(child: Text('Error retrieving todo tasks.'));
                  }
                  List<TodoTaskModel> tasks = snapshot.data!;

                  // Apply search filter
                  if (searchQuery.isNotEmpty) {
                    tasks = tasks.where((task) =>
                        task.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        task.description.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                  }

                  // Apply status filter
                  if (filterStatus != 'All') {
                    tasks = tasks.where((task) => task.status == filterStatus).toList();
                  }

                  if (tasks.isEmpty) {
                    return const Center(child: Text('No todo tasks found.'));
                  }

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return FutureBuilder<UserModel?>(
                        future: userService.getUserById(task.assignedTo),
                        builder: (context, userSnapshot) {
                          String assignedToName = 'Loading...';
                          if (userSnapshot.connectionState == ConnectionState.done) {
                            if (userSnapshot.hasError || !userSnapshot.hasData) {
                              assignedToName = 'Unavailable';
                            } else {
                              assignedToName = userSnapshot.data!.name;
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                            child: ListTile(
                              leading: getStatusIcon(task.status),
                              title: Text(task.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Assigned To: $assignedToName'),
                                  Text('Status: ${task.status}'),
                                  Text('Due Date: ${task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!.toDate()) : 'N/A'}'),
                                  const SizedBox(height: 4.0),
                                  // Progress Bar
                                  LinearProgressIndicator(
                                    value: task.percentageCompleted / 100,
                                    backgroundColor: Colors.grey[300],
                                    color: getProgressColor(task.percentageCompleted),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text('${task.percentageCompleted}% Completed'),
                                ],
                              ),
                              trailing: Text(DateFormat('yyyy-MM-dd').format(task.createdAt.toDate())),
                              isThreeLine: true,
                              onTap: () => _showTaskDetails(task),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon getStatusIcon(String status) {
    switch (status) {
      case 'Assigned':
        return const Icon(Icons.assignment, color: Colors.blue);
      case 'Accepted':
        return const Icon(Icons.assignment_turned_in, color: Colors.orange);
      case 'In Progress':
        return const Icon(Icons.work, color: Colors.yellow);
      case 'Completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  Color getProgressColor(int percentage) {
    if (percentage >= 75) {
      return Colors.green;
    } else if (percentage >= 50) {
      return Colors.lightGreen;
    } else if (percentage >= 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _showTaskDetails(TodoTaskModel task) async {
  final userService = Provider.of<UserService>(context, listen: false);

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              // Description Section
              Row(
                children: const [
                  Icon(Icons.description, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text(
                    'Description:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(task.description, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              // Assigned To Section
              Row(
                children: const [
                  Icon(Icons.person, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Assigned To:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              FutureBuilder<UserModel?>(
                future: userService.getUserById(task.assignedTo),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text('Unavailable', style: TextStyle(fontSize: 16));
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${snapshot.data!.name} (${snapshot.data!.email})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Assigned By Section (Now fetching admin details)
              Row(
                children: const [
                  Icon(Icons.person_outline, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text(
                    'Assigned By:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              FutureBuilder<UserModel?>(
                future: userService.getUserById(task.assignedBy),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text('Unavailable', style: TextStyle(fontSize: 16));
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${snapshot.data!.name} (${snapshot.data!.email})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Status Section
              Row(
                children: const [
                  Icon(Icons.timelapse, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Status:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(task.status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              // Progress Section
              Row(
                children: const [
                  Icon(Icons.percent, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Progress:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                '${task.percentageCompleted}% - ${task.progressDescription.isNotEmpty ? task.progressDescription : 'N/A'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              // Date Information Section
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Created At: ${DateFormat('yyyy-MM-dd').format(task.createdAt.toDate())}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Due Date: ${task.dueDate != null ? DateFormat('yyyy-MM-dd').format(task.dueDate!.toDate()) : 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    },
  );
}

}
