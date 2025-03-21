// lib/screens/messaging/chat_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:provider/provider.dart';

import '../../services/messaging_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../widgets/chat_message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel peerUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.peerUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();

  bool _isLoading = false;
  bool _isRecorderInitialized = false;

  // For the single-player approach:
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayerInit = false;
  bool _isPlaying = false;
  Duration _currentPos = Duration.zero;
  Duration _totalDur = Duration.zero;
  String? _playingUrl; // the audioUrl currently playing
  StreamSubscription? _playerSub;

  // Recording states
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  StreamSubscription? _recorderSub;

  late MessagingService _messagingService;
  late UserService _userService;
  String? _currentUserId;

  // Peer presence
  Stream<DocumentSnapshot>? _peerStatusStream;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messagingService = Provider.of<MessagingService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);

    // Setup peer presence stream only once
    _peerStatusStream ??= FirebaseFirestore.instance
        .collection('users')
        .doc(widget.peerUser.userId)
        .snapshots();
  }

  // ------------- AUDIO RECORDER -------------
  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice notes.'),
        ),
      );
      return;
    }
    try {
      await _audioRecorder.openRecorder();
      // Update every 200ms
      _audioRecorder.setSubscriptionDuration(const Duration(milliseconds: 200));

      _recorderSub = _audioRecorder.onProgress?.listen((event) {
        if (event != null) {
          setState(() {
            _recordDuration = event.duration;
          });
        }
      });

      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing recorder: $e')),
      );
    }
  }

  // ------------- SINGLE AUDIO PLAYER -------------
  Future<void> _initPlayer() async {
    await _player.openPlayer();
    // Let onProgress fire ~5 times a second
    _player.setSubscriptionDuration(const Duration(milliseconds: 200));

    _playerSub = _player.onProgress?.listen((event) {
      if (event != null) {
        setState(() {
          _currentPos = event.position;
          _totalDur = event.duration;
          _isPlaying = _player.isPlaying;
        });
      }
    });

    setState(() {
      _isPlayerInit = true;
    });
  }

  /// Called by the bubble to play/pause a certain audio URL
  Future<void> playOrPauseAudio(String url) async {
    if (!_isPlayerInit) return;

    // If tapping the same URL while playing => pause
    if (_isPlaying && _playingUrl == url) {
      await _player.pausePlayer();
      return;
    }

    // If we are playing a different file, stop it first
    if (_playingUrl != null && _playingUrl != url) {
      await _player.stopPlayer();
    }

    // If currently paused that same url => resume
    // but flutter_sound doesn't have a direct resume, so we do startPlayer again
    // We'll keep it simple: always do startPlayer from the beginning
    // For a real resume, you'd track the last position, etc.

    // Start playing the new track
    await _player.startPlayer(
      fromURI: url,
      whenFinished: () {
        setState(() {
          _isPlaying = false;
          _currentPos = Duration.zero;
          _playingUrl = null;
        });
      },
    );

    setState(() {
      _playingUrl = url;
      // isPlaying is set automatically by onProgress
    });
  }

  /// Called by bubble slider to seek within the current track
  Future<void> seekAudio(String url, double milliseconds) async {
    if (_playingUrl == url) {
      final pos = Duration(milliseconds: milliseconds.toInt());
      await _player.seekToPlayer(pos);
    }
  }

  /// Check if a bubble's audio is the currently playing one
  bool isAudioPlaying(String url) => (_playingUrl == url) && _isPlaying;
  Duration currentAudioPosition(String url) =>
      (_playingUrl == url) ? _currentPos : Duration.zero;
  Duration totalAudioDuration(String url) =>
      (_playingUrl == url) ? _totalDur : Duration.zero;

  @override
  void dispose() {
    _recorderSub?.cancel();
    _audioRecorder.closeRecorder();

    _playerSub?.cancel();
    _player.closePlayer();

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current user from provider
    final user = context.watch<UserProvider>().user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.peerUser.name)),
        body: const Center(child: Text("User not logged in or still loading...")),
      );
    }
    if (_currentUserId == null) {
      _currentUserId = user.userId;
      _userService.setUserOnline(_currentUserId!);
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildMessagesList()),
              if (_isLoading) const LinearProgressIndicator(),
              _buildInputArea(),
            ],
          ),
          if (_isRecording) _buildRecordingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: _buildPeerPresence(),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildPeerPresence() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _peerStatusStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(widget.peerUser.name);
        }
        final userDoc = snapshot.data!;
        final isOnline = userDoc['isOnline'] ?? false;
        final Timestamp? lastSeen = userDoc['lastSeen'];
        String subtitle;
        if (isOnline) {
          subtitle = 'Online';
        } else if (lastSeen != null) {
          final dt = lastSeen.toDate();
          subtitle = 'Last seen: ${DateFormat('yyyy-MM-dd HH:mm').format(dt)}';
        } else {
          subtitle = 'Offline';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerUser.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildMessagesList() {
    if (_currentUserId == null || widget.chatId.isEmpty) {
      return const Center(child: Text('Cannot load messages.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _messagingService.getMessagesStream(widget.chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(child: Text('Start the conversation!'));
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final doc = messages[index];
            final messageId = doc.id;
            final messageData = doc.data() as Map<String, dynamic>;
            final isMe = messageData['senderId'] == _currentUserId;

            return GestureDetector(
              onLongPress: isMe ? () => _showDeleteMenu(messageId) : null,
              child: ChatMessageBubble(
                messageData: messageData,
                isMe: isMe,
                // pass reference of 'this' to let bubble call the single-player methods
                chatScreenState: this,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
              onPressed: _showAttachmentOptions,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type message or hold mic',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
                onSubmitted: (value) => _sendMessage(text: value),
              ),
            ),
            GestureDetector(
              onLongPressStart: (_) => _onMicLongPress(),
              onLongPressEnd: (_) => _onMicLongPressEnd(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blueAccent),
              onPressed: () => _sendMessage(text: _messageController.text),
            ),
          ],
        ),
      ),
    );
  }

  // A top overlay that appears while recording
  Widget _buildRecordingOverlay() {
    final secs = _recordDuration.inSeconds % 60;
    final mins = _recordDuration.inMinutes % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 60,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'Recording...  $timeStr',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Recording logic
  void _onMicLongPress() async {
    if (!_isRecorderInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recorder not initialized or mic permission denied')),
      );
      return;
    }
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    try {
      await _audioRecorder.startRecorder(
        toFile: 'voice_note.aac',
        codec: Codec.aacADTS,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _onMicLongPressEnd() async {
    setState(() {
      _isRecording = false;
    });
    String? path;
    try {
      path = await _audioRecorder.stopRecorder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recorder: $e')),
      );
      return;
    }
    if (path == null) return; // no file recorded

    // Auto-send approach
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_voice.aac';
      final storageRef = FirebaseStorage.instance.ref('chat_audio/$fileName');
      await storageRef.putFile(File(path));
      final audioUrl = await storageRef.getDownloadURL();
      await _sendMessage(audioUrl: audioUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending voice note: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Send message logic
  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    if (_currentUserId == null) return;
    if ((text == null || text.isEmpty) &&
        (imageUrl == null || imageUrl.isEmpty) &&
        (audioUrl == null || audioUrl.isEmpty)) {
      return;
    }
    final messageData = {
      'senderId': _currentUserId,
      'text': text ?? '',
      'imageUrl': imageUrl ?? '',
      'audioUrl': audioUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'deleted': false,
    };
    try {
      setState(() => _isLoading = true);
      await _messagingService.sendMessage(widget.chatId, messageData);
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Picks image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (pickedImage != null) {
        final confirmed = await _confirmSendDialog(
          context,
          title: 'Send Image?',
          contentWidget: Image.file(File(pickedImage.path), height: 200),
        );
        if (!confirmed) return;

        setState(() => _isLoading = true);

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedImage.name}';
        final storageRef =
            FirebaseStorage.instance.ref('chat_images/$fileName');
        await storageRef.putFile(File(pickedImage.path));
        final url = await storageRef.getDownloadURL();
        await _sendMessage(imageUrl: url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Picks image from gallery
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedImage != null) {
        final confirmed = await _confirmSendDialog(
          context,
          title: 'Send Image?',
          contentWidget: Image.file(File(pickedImage.path), height: 200),
        );
        if (!confirmed) return;

        setState(() => _isLoading = true);

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedImage.name}';
        final storageRef =
            FirebaseStorage.instance.ref('chat_images/$fileName');
        await storageRef.putFile(File(pickedImage.path));
        final url = await storageRef.getDownloadURL();
        await _sendMessage(imageUrl: url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmSendDialog(
    BuildContext context, {
    required String title,
    String? content,
    Widget? contentWidget,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content:
              contentWidget ?? (content != null ? Text(content) : const SizedBox.shrink()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showDeleteMenu(String messageId) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(50, 50, 0, 0),
      items: const [
        PopupMenuItem(value: 'me', child: Text('Delete for me')),
        PopupMenuItem(value: 'everyone', child: Text('Delete for everyone')),
      ],
    ).then((value) async {
      try {
        if (value == 'me') {
          await _messagingService.deleteMessageForSenderOnly(
            widget.chatId,
            messageId,
            _currentUserId ?? '',
          );
        } else if (value == 'everyone') {
          await _messagingService.deleteMessageForBoth(widget.chatId, messageId);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
        );
      }
    });
  }
}
