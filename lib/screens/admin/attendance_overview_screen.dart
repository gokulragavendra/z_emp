import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/attendance_service.dart';
import 'user_attendance_detail_screen.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  _AttendanceOverviewScreenState createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true; // Indicates initial loading
  bool _isRefreshing = false; // Indicates pull-to-refresh state

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// Loads users (excluding the current admin) and checks clock-in status.
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final snapshot = await _db.collection('users').get();

      final List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'] ?? '';
        // Exclude admin and the current user from the list
        if (role != 'admin' && doc.id != currentUser?.uid) {
          final isClockedIn = await _isUserClockedIn(doc.id);
          users.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'isClockedIn': isClockedIn,
          });
        }
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors by showing a SnackBar
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  /// Pull-to-refresh method that re-calls [_loadUsers].
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _loadUsers();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Checks if a user is currently clocked in.
  Future<bool> _isUserClockedIn(String userId) async {
    final attendanceService = AttendanceService();
    return await attendanceService.isUserClockedIn(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Overview'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _users.isEmpty
                  ? const ListEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              child: Text(
                                user['name'].isNotEmpty
                                    ? user['name'][0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                            title: Text(
                              user['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              user['isClockedIn']
                                  ? 'Clocked In'
                                  : 'Clocked Out',
                              style: TextStyle(
                                fontSize: 16,
                                color: user['isClockedIn']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            trailing: Icon(
                              user['isClockedIn']
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: user['isClockedIn']
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserAttendanceDetailScreen(
                                    userId: user['id'],
                                    userName: user['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// A simple widget indicating an empty list scenario.
class ListEmptyState extends StatelessWidget {
  const ListEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No users found.'));
  }
}
