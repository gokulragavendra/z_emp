import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({Key? key}) : super(key: key);

  @override
  State<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen> {
  bool _isDeleting = false; // Tracks whether a delete operation is in progress
  bool _isRefreshing = false; // Tracks whether a pull-to-refresh is in progress

  /// Confirms whether the user really wants to delete an announcement.
  Future<bool> _confirmDeletion(BuildContext dialogContext) async {
    return showDialog<bool>(
      context: dialogContext,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content:
              const Text('Are you sure you want to delete this announcement?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) //
        .then((value) => value ?? false);
  }

  /// (Optional) Allows a manual "pull-to-refresh" to re-fetch announcements.
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await Provider.of<AnnouncementProvider>(context, listen: false)
          .fetchAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing announcements: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcementProvider = Provider.of<AnnouncementProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Announcements'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Show a dialog to add an announcement
          await showDialog(
            context: context,
            builder: (_) => const _AnnouncementDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          // If we're not loading or deleting, allow user to pull down to refresh
          if (!announcementProvider.isLoading && !_isDeleting)
            RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: announcementProvider.announcements.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final announcement =
                      announcementProvider.announcements[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      title: Text(
                        announcement.title,
                        style: TextStyle(
                          fontWeight: announcement.pinned
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: announcement.pinned
                              ? Colors.redAccent
                              : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          announcement.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.redAccent,
                        onPressed: () async {
                          final confirmed = await _confirmDeletion(context);
                          if (!confirmed) return; // user canceled

                          setState(() => _isDeleting = true);
                          try {
                            await announcementProvider.removeAnnouncement(
                              announcement.id,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Announcement deleted'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error deleting announcement: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isDeleting = false);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

          // If the provider is loading or we're deleting, show a spinner
          if (announcementProvider.isLoading || _isDeleting)
            const Center(child: CircularProgressIndicator()),

          // If user manually pulls down to refresh, show a small spinner near top
          if (_isRefreshing)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 60.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isPinned = false;
  final List<String> _allRoles = [
    'all',
    'admin',
    'manager',
    'sales',
    'measurement'
  ];
  final List<String> _selectedRoles = ['all']; // Default to 'all'
  bool _isProcessing = false; // indicates the "add announcement" in progress

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return AlertDialog(
      title: const Text('Add Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text("Pin this announcement"),
              value: _isPinned,
              onChanged: (val) {
                setState(() {
                  _isPinned = val ?? false;
                });
              },
            ),
            const SizedBox(height: 12),
            const Text('Select Target Roles:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _allRoles.map((role) {
                final selected = _selectedRoles.contains(role);
                return FilterChip(
                  label: Text(role.toUpperCase()),
                  selected: selected,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        if (role == 'all') {
                          _selectedRoles.clear();
                          _selectedRoles.add('all');
                        } else {
                          _selectedRoles.remove('all');
                          _selectedRoles.add(role);
                        }
                      } else {
                        _selectedRoles.remove(role);
                        if (_selectedRoles.isEmpty) {
                          _selectedRoles.add('all');
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing
              ? null
              : () async {
                  // Validate input fields
                  if (_titleController.text.trim().isEmpty ||
                      _messageController.text.trim().isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields.'),
                      ),
                    );
                    return;
                  }
                  setState(() => _isProcessing = true);

                  final provider = Provider.of<AnnouncementProvider>(
                    context,
                    listen: false,
                  );
                  try {
                    await provider.addAnnouncement(
                      _titleController.text.trim(),
                      _messageController.text.trim(),
                      _isPinned,
                      _selectedRoles,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Announcement added successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error adding announcement: $e'),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isProcessing = false);
                    }
                  }
                },
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
