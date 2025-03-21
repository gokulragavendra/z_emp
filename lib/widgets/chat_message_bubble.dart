import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';

// Updated ChatMessageBubble with the extra property
class ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isMe;

  // NEW property: reference to ChatScreen's state (or any "controller" you prefer).
  final dynamic chatScreenState; 
  // If you specifically want `_ChatScreenState chatScreenState`, you can declare
  // `final _ChatScreenState chatScreenState;` but you might need an import to that state.
  // For now, we'll store it in a `dynamic` to avoid import errors.

  const ChatMessageBubble({
    Key? key,
    required this.messageData,
    required this.isMe,
    required this.chatScreenState, // added param
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool deleted = messageData['deleted'] ?? false;
    String text = deleted ? 'Message deleted' : (messageData['text'] ?? '');
    String imageUrl = messageData['imageUrl'] ?? '';
    String audioUrl = messageData['audioUrl'] ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: _buildBubbleGradient(isMe),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: _buildInner(deleted, text, imageUrl, audioUrl),
          ),
        ),
      ),
    );
  }

  LinearGradient _buildBubbleGradient(bool isMe) {
    if (isMe) {
      // “Sent bubble” gradient
      return const LinearGradient(
        colors: [Color(0xFF784BA0), Color(0xFF2B86C5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // “Received bubble” gradient
      return const LinearGradient(
        colors: [Color(0xFFEDE574), Color(0xFFE1F5C4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Widget _buildInner(
    bool deleted,
    String text,
    String imageUrl,
    String audioUrl,
  ) {
    if (deleted) {
      return Text(
        'Message deleted',
        style: TextStyle(
          color: isMe ? Colors.white70 : Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
          ),
        const SizedBox(height: 4),
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        if (audioUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          AudioPlayerBubble(audioUrl: audioUrl, isMe: isMe),
        ],
      ],
    );
  }
}

// Upgraded AudioPlayerBubble with a Slider for progress
class AudioPlayerBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const AudioPlayerBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<AudioPlayerBubble> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayerInited = false;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();
    setState(() {
      _isPlayerInited = true;
    });

    // Listen to changes in player state
    _playerSubscription = _player.onProgress?.listen((event) {
      if (event != null) {
        setState(() {
          currentPosition = event.position;
          totalDuration = event.duration;
          isPlaying = _player.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!_isPlayerInited) return;

    if (isPlaying) {
      await _player.pausePlayer();
    } else {
      // Start or resume playing
      await _player.startPlayer(
        fromURI: widget.audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {
            isPlaying = false;
            currentPosition = Duration.zero;
          });
        },
      );
    }
  }

  // If you want user to seek, you can do a _player.seekTo(duration) in onChanged
  Future<void> _onSeek(double value) async {
    final position = Duration(milliseconds: value.toInt());
    await _player.seekToPlayer(position);
  }

  String _formatDuration(Duration d) {
    final secs = d.inSeconds % 60;
    final mins = d.inMinutes % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isMe ? Colors.blue[400] : Colors.grey[300];
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    final double maxSliderValue = totalDuration.inMilliseconds.toDouble();
    final double currentSliderValue = currentPosition.inMilliseconds.toDouble();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            color: textColor,
            iconSize: 28,
            onPressed: _togglePlayPause,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: textColor,
                inactiveTrackColor: textColor.withOpacity(0.3),
                thumbColor: textColor,
                overlayColor: textColor.withOpacity(0.2),
              ),
              child: Slider(
                min: 0.0,
                max: maxSliderValue,
                value: (currentSliderValue <= maxSliderValue)
                    ? currentSliderValue
                    : 0.0,
                onChanged: (val) async {
                  // optional: let user manually seek
                  await _onSeek(val);
                },
              ),
            ),
          ),
          Text(
            _formatDuration(isPlaying ? currentPosition : totalDuration),
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
