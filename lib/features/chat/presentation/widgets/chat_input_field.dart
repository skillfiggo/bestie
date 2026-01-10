import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;

class ChatInputField extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onImagePressed;
  final VoidCallback? onVideoCallPressed;
  final VoidCallback? onVoiceCallPressed;
  final Function(String path, int duration)? onSendVoiceNote;

  const ChatInputField({
    super.key,
    required this.onSendMessage,
    this.onImagePressed,
    this.onVideoCallPressed,
    this.onVoiceCallPressed,
    this.onSendVoiceNote,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _hasText = false;
  bool _isRecording = false;
  bool _isCancelled = false;
  bool _showEmoji = false;
  Timer? _timer;
  int _recordDuration = 0;
  final double _cancelThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  void _toggleEmojiKeyboard() {
    if (_showEmoji) {
      // Show keyboard
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      // Show emoji picker
      FocusScope.of(context).unfocus();
      setState(() => _showEmoji = true);
    }
  }

  DateTime? _startTime;

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission is required')),
            );
          }
          return;
        }
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: path);
      _startTime = DateTime.now();
      debugPrint('🎤 Recording started at: $path');
      
      setState(() {
        _isRecording = true;
        _isCancelled = false;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
      
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _timer?.cancel();
    // Safety check if not recording
    if (!_isRecording && !await _audioRecorder.isRecording()) return;
    
    String? path;
    try {
       path = await _audioRecorder.stop();
    } catch (e) {
       debugPrint('Error stopping recorder: $e');
    }
    
    final duration = _startTime != null 
        ? DateTime.now().difference(_startTime!).inSeconds 
        : _recordDuration;

    setState(() {
      _isRecording = false;
    });

    if (send && !_isCancelled && path != null && widget.onSendVoiceNote != null) {
      final file = File(path);
      if (await file.exists() && await file.length() > 0) {
         if (duration < 1) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice note too short')),
              );
            }
            return;
         }
         widget.onSendVoiceNote!(path, duration);
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to record voice note')),
            );
         }
      }
    }
  }

  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    final offset = details.localOffsetFromOrigin;
    if (offset.dy < -_cancelThreshold || offset.dx < -_cancelThreshold) {
       if (!_isCancelled) setState(() => _isCancelled = true);
    } else {
       if (_isCancelled) setState(() => _isCancelled = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
      setState(() {
        _hasText = false; 
        _showEmoji = false; // Close picker on send? Optional.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 10,
             offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isRecording ? _buildRecordingUI() : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                        // Emoji button
                        IconButton(
                          icon: Icon(
                            _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                            color: AppColors.textSecondary, 
                            size: 24
                          ),
                          onPressed: _toggleEmojiKeyboard,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: _hasText ? AppColors.primary : AppColors.textSecondary,
                            size: 24,
                          ),
                          onPressed: _hasText ? _handleSend : null,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppColors.primary,
                    onPressed: widget.onVideoCallPressed ?? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Video call coming soon!')),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    color: AppColors.primary,
                    onPressed: widget.onVoiceCallPressed ?? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice call coming soon!')),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.image_rounded,
                    label: 'Image',
                    color: AppColors.primary,
                    onPressed: widget.onImagePressed ?? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Image picker coming soon!')),
                      );
                    },
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(send: !_isCancelled),
                    onLongPressMoveUpdate: _handleDragUpdate,
                    onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Press and hold to record'), duration: Duration(seconds: 1)),
                          );
                    },
                    child: _ActionButton(
                      icon: _isRecording && !_isCancelled ? Icons.mic : Icons.mic_none,
                      label: _isRecording ? (_isCancelled ? 'Cancel' : 'Record') : 'Voice',
                      color: _isRecording 
                        ? (_isCancelled ? Colors.red : AppColors.primary)
                        : AppColors.primary,
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
            
            // Emoji Picker
            if (_showEmoji)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  textEditingController: _controller,
                  config: Config(
                    height: 250,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: Colors.white,
                      columns: 7,
                      emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.20 : 1.0),
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      indicatorColor: AppColors.primary,
                      iconColorSelected: AppColors.primary,
                      iconColor: Colors.grey,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      enabled: false,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    final minutes = (_recordDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordDuration % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (!_isCancelled)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
            )
          else 
            const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            
          const SizedBox(width: 12),
          
          Text(
            _isCancelled ? 'Release to cancel' : '$minutes:$seconds',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _isCancelled ? Colors.red : AppColors.textPrimary,
            ),
          ),
          
          if (!_isCancelled) ...[
            const Spacer(),
            const Text(
              '<< Slide to cancel',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
