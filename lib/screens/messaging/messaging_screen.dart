// lib/screens/messaging/messaging_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/messaging_service.dart';
import '../../services/user_service.dart';
import '../messaging/chat_screen.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  late MessagingService messagingService;
  late UserService userService;
  // Remove the local userProvider field assignment with listen: false

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    messagingService = Provider.of<MessagingService>(context, listen: false);
    userService = Provider.of<UserService>(context, listen: false);
    // No need to assign userProvider here because we want to listen for changes.
  }

  Future<void> _startChat(UserModel peerUser) async {
    // Get the current user from Provider (listening is not critical here)
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not available. Please try again.')),
      );
      return;
    }
    try {
      final chatId = await messagingService.getChatId(
        currentUser.userId,
        peerUser.userId,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, peerUser: peerUser),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  Future<void> _selectUserToChat() async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not available. Please try again.')),
      );
      return;
    }
    try {
      final allUsers = await userService.getUsers();
      final otherUsers =
          allUsers.where((u) => u.userId != currentUser.userId).toList();
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return ListView.builder(
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final user = otherUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  ),
                ),
                title: Text(user.name),
                onTap: () {
                  Navigator.pop(context);
                  _startChat(user);
                },
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching users: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Now, get the user provider with listening enabled.
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.user;
    if (currentUser == null) {
      // This will rebuild as soon as the user is loaded.
      return const Scaffold(
        body: Center(
          child: Text('User not logged in. Please login again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: messagingService.getUserChats(currentUser.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data!.docs;
          if (chats.isEmpty) {
            return const Center(child: Text('No chats yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final participants = List<String>.from(chatData['participants']);
              final peerId = participants.firstWhere(
                (id) => id != currentUser.userId,
                orElse: () => '',
              );
              if (peerId.isEmpty) return const SizedBox();
              return FutureBuilder<UserModel?>(
                future: userService.getUserById(peerId),
                builder: (context, peerSnapshot) {
                  if (!peerSnapshot.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }
                  final peerUser = peerSnapshot.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        peerUser.name.isNotEmpty
                            ? peerUser.name[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(peerUser.name),
                    subtitle: const Text('Tap to chat'),
                    onTap: () => _startChat(peerUser),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: _selectUserToChat,
        child: const Icon(Icons.message),
      ),
    );
  }
}
