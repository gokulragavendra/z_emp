import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_service.dart';
import '../../models/user_model.dart';
import 'user_form_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late UserService userService;
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];

  /// Shows a spinner while loading user data.
  bool _isLoading = false;

  /// Shows a spinner overlay for destructive or save operations.
  bool _isOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    userService = Provider.of<UserService>(context, listen: false);
    _loadUsers();
  }

  /// Fetches user data with basic error handling.
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await userService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _filteredUsers = users;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Filters the user list based on the search query.
  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users
          .where((user) =>
              user.name.toLowerCase().contains(query.toLowerCase()) ||
              user.email.toLowerCase().contains(query.toLowerCase()) ||
              user.role.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  /// Opens the UserFormDialog to either add or edit a user.
  /// If the dialog returns true, we reload the user list.
  Future<void> _openUserForm({UserModel? user}) async {
    final bool? result = await showDialog(
      context: context,
      builder: (context) => UserFormDialog(user: user),
    );
    if (result == true) {
      _loadUsers();
    }
  }

  /// Confirms and deletes a user with an overlay spinner during operation.
  Future<void> _deleteUser(UserModel user) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${user.name}?'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isOperationInProgress = true);
      try {
        await userService.deleteUser(user.userId);
        await _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isOperationInProgress = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('User Management'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildUserList(currentUserId),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openUserForm(),
            child: const Icon(Icons.add),
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
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Search Users',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: _filterUsers,
    );
  }

  Widget _buildUserList(String? currentUserId) {
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return ListView.separated(
      itemCount: _filteredUsers.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(user.name.substring(0, 1).toUpperCase()),
          ),
          title: Text(user.name),
          subtitle:
              Text('${user.role} - ${user.isActive ? 'Active' : 'Inactive'}'),
          trailing: user.userId != currentUserId
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openUserForm(user: user);
                    } else if (value == 'delete') {
                      _deleteUser(user);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              : null,
          onTap: () {
            if (user.userId != currentUserId) {
              _openUserForm(user: user);
            }
          },
        );
      },
    );
  }
}
