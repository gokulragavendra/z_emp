import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../services/todo_task_service.dart';
import '../../services/user_service.dart';
import '../../models/todo_task_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
// Import the localization utility
import '../../l10n/app_localizations.dart';

class AdminTodoTaskAssignmentScreen extends StatefulWidget {
  const AdminTodoTaskAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<AdminTodoTaskAssignmentScreen> createState() =>
      _AdminTodoTaskAssignmentScreenState();
}

class _AdminTodoTaskAssignmentScreenState
    extends State<AdminTodoTaskAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _dueDate;
  UserModel? _selectedUser;

  bool _isFetchingUsers = true; // For fetching user list
  bool _isOperationInProgress = false; // For assigning the task

  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  /// Pull-to-refresh support
  Future<void> _onRefresh() async {
    setState(() => _isFetchingUsers = true);
    await _fetchUsers();
  }

  /// Fetch users with roles 'Sales Staff', 'Measurement Staff', 'Manager'.
  Future<void> _fetchUsers() async {
    final userService = Provider.of<UserService>(context, listen: false);

    try {
      final fetchedUsers = await userService.getUsersByRoles([
        'Sales Staff',
        'Measurement Staff',
        'Manager',
      ]);

      if (!mounted) return;
      setState(() {
        _users = fetchedUsers;
        _isFetchingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingUsers = false);

      // Show the error in a SnackBar. We're simply concatenating the error text.
      print("Error fetching users: $e"); // Logging the error for debugging

      if (mounted) {
        final localization = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localization.translate("error_fetching_users") + e.toString(),
            ),
          ),
        );
      }
    }
  }

  /// Shows a confirmation dialog before assigning the task.
  void _confirmAssignment() {
    final localization = AppLocalizations.of(context)!;

    // Validate the form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userName = _selectedUser?.name ?? "";
    final dueDateText =
        _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : '---';

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localization.translate("confirm_assignment")),
        content: Text(
          // Build the message from smaller localized pieces
          localization.translate("confirm_assignment_message_prefix") +
              "\"$userName\"" +
              localization.translate("confirm_assignment_message_suffix") +
              dueDateText +
              "?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localization.translate("cancel")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localization.translate("yes")),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _assignTodoTask();
      }
    });
  }

  /// Actually assigns the new task if user confirms.
  Future<void> _assignTodoTask() async {
    final localization = AppLocalizations.of(context)!;
    final todoTaskService =
        Provider.of<TodoTaskService>(context, listen: false);
    final currentAdmin = Provider.of<UserProvider>(context, listen: false).user;

    setState(() => _isOperationInProgress = true);

    try {
      final taskId = const Uuid().v4();
      final newTask = TodoTaskModel(
        taskId: taskId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _selectedUser!.userId,
        assignedBy: currentAdmin?.userId ?? 'admin_default',
        status: 'Assigned',
        percentageCompleted: 0,
        progressDescription: '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        dueDate: Timestamp.fromDate(_dueDate!),
      );

      await todoTaskService.assignTodoTask(newTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate("assign_todo_task_success")),
        ),
      );

      // Clear fields
      print("Task assigned successfully."); // Logging successful assignment

      _formKey.currentState!.reset();
      setState(() {
        _selectedUser = null;
        _dueDate = null;
      });
      _titleController.clear();
      _descriptionController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localization.translate("error_assigning_todo_task") + e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  /// Optional: Let the user reset all fields after a confirmation
  Future<void> _resetForm() async {
    final localization = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localization.translate("confirm")),
        content: Text(localization.translate("clear_all_fields_confirm")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localization.translate("cancel")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localization.translate("yes")),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _formKey.currentState!.reset();
      setState(() {
        _selectedUser = null;
        _dueDate = null;
      });
      _titleController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate("fields_cleared_message")),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate("assign_todo_task")),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Optional: manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isFetchingUsers = true);
              _fetchUsers();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Subtle background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main content with pull-to-refresh
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                child: _isFetchingUsers
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(localization.translate("loading_please_wait")),
                          ],
                        ),
                      )
                    : _buildForm(context),
              ),
            ),
          ),
          if (_isOperationInProgress)
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

  Widget _buildForm(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localization.translate("no_users_found_task")),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isFetchingUsers = true);
                _fetchUsers();
              },
              child: Text(localization.translate("retry")),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                localization.translate("assign_a_todo_task_to_a_user"),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),

              // User Autocomplete
              _buildUserAutocomplete(),

              const SizedBox(height: 16.0),
              // Task Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: localization.translate("task_title_required"),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? localization.translate("please_enter_task_title")
                    : null,
              ),
              const SizedBox(height: 16.0),
              // Task Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText:
                      localization.translate("task_description_required"),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty
                    ? localization.translate("please_enter_task_description")
                    : null,
              ),
              const SizedBox(height: 16.0),

              // Due Date
              _buildDueDateField(),

              const SizedBox(height: 16.0),
              // Buttons row with "Assign Task" and "Reset Form"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _confirmAssignment,
                    child: Text(localization.translate("assign_todo_task")),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _resetForm,
                    child: Text(localization.translate("reset_form_button")),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAutocomplete() {
    final localization = AppLocalizations.of(context)!;

    return Autocomplete<UserModel>(
      displayStringForOption: (UserModel option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<UserModel>.empty();
        }
        return _users
            .where((UserModel user) => user.name
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase()))
            .take(10);
      },
      onSelected: (UserModel selection) {
        setState(() => _selectedUser = selection);
      },
      fieldViewBuilder:
          (context, textController, focusNode, onEditingComplete) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: localization.translate("assign_to_required"),
            border: const OutlineInputBorder(),
            suffixIcon: _selectedUser != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      textController.clear();
                      setState(() => _selectedUser = null);
                    },
                  )
                : null,
          ),
          validator: (value) {
            if (_selectedUser == null) {
              return localization
                  .translate("please_select_user_to_assign_task");
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildDueDateField() {
    final localization = AppLocalizations.of(context)!;

    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: _dueDate != null
            ? localization.translate("due_date_label_prefix") +
                DateFormat('yyyy-MM-dd').format(_dueDate!)
            : localization.translate("select_due_date_required"),
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final now = DateTime.now();
        try {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dueDate ?? now,
            firstDate: now,
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setState(() => _dueDate = picked);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                // No placeholders for translate, so we do string concat:
                localization.translate("error_picking_date") + e.toString(),
              ),
            ),
          );
        }
      },
      validator: (value) => _dueDate == null
          ? localization.translate("please_select_due_date")
          : null,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
