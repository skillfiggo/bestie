import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/ai_chat/domain/models/ai_models.dart';
import 'package:bestie/features/ai_chat/data/providers/ai_chat_providers.dart';
import 'package:bestie/core/utils/image_utils.dart';

/// Chat screen for conversing with an AI companion.
/// Messages are kept in-memory only — cleared when the user leaves.
class AiChatScreen extends ConsumerStatefulWidget {
  final AiProfileModel aiProfile;

  const AiChatScreen({super.key, required this.aiProfile});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isImageLoading = false; // Separate flag for image generation
  bool _isVideoLoading = false; // Separate flag for video generation
  String? _errorMessage; // Tracks the last friendly error to show in-chat

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // Messages are discarded when leaving — ephemeral by design
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // 0.0 is the bottom in a reversed ListView
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading || _isImageLoading || _isVideoLoading) return;

    _textController.clear();

    final lowercaseText = text.toLowerCase();

    // Check if user is requesting a video
    final videoKeywords = ['video', 'clip', 'reel', 'film', 'movie'];
    final shouldTriggerVideo = videoKeywords.any((keyword) => lowercaseText.contains(keyword));

    if (shouldTriggerVideo) {
      _showVideoConfirmation(userPrompt: text);
      return;
    }

    // Check if user is requesting a photo/image
    final imageKeywords = ['picture', 'photo', 'image', 'pic', 'pix'];
    final shouldTriggerImage = imageKeywords.any((keyword) => lowercaseText.contains(keyword));

    if (shouldTriggerImage) {
      _handleRequestImage(userPrompt: text);
      return;
    }

    // Add user message to local state
    setState(() {
      _messages.add(AiChatMessage(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final reply = await ref.read(aiChatRepositoryProvider).sendMessage(
            aiProfileId: widget.aiProfile.id,
            newMessage: text,
            conversationHistory: _messages,
          );

      if (mounted) {
        setState(() {
          _messages.add(AiChatMessage(
            role: 'assistant',
            content: reply,
            createdAt: DateTime.now(),
          ));
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint('AI Chat Send Message Error: $e');
      if (mounted) {
        final rawError = e.toString().replaceAll('Exception: ', '').toLowerCase();
        final String friendlyError;

        if (rawError.contains('insufficient coins') || rawError.contains('402')) {
          friendlyError =
              "You need more coins to keep chatting with ${widget.aiProfile.name}. Top up and come back! 💰";
        } else if (rawError.contains('unavailable') ||
            rawError.contains('502') ||
            rawError.contains('bad gateway') ||
            rawError.contains('temporarily')) {
          friendlyError =
              "${widget.aiProfile.name} is not online right now 💔 Try again in a moment.";
        } else if (rawError.contains('profile not found') ||
            rawError.contains('unavailable') ||
            rawError.contains('403')) {
          friendlyError =
              "${widget.aiProfile.name} is currently unavailable. Check back soon! 🌙";
        } else if (rawError.contains('empty') || rawError.contains('null')) {
          friendlyError =
              "${widget.aiProfile.name} didn't respond. Try sending your message again! 💬";
        } else {
          friendlyError =
              "${widget.aiProfile.name} is not online right now 💔 Please try again later.";
        }

        setState(() {
          _isLoading = false;
          _errorMessage = friendlyError;
        });

        // Auto-clear error after 6 seconds
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    }
  }

  /// Shows a coin-cost confirmation dialog before generating a video.
  Future<void> _showVideoConfirmation({String? userPrompt}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Request a Video',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: 'This will cost '),
                    TextSpan(
                      text: '150 coins',
                      style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: ' to generate a short personalised video clip.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Send 150 🪙',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      _handleRequestVideo(userPrompt: userPrompt);
    }
  }

  /// Request a video from the AI companion.
  Future<void> _handleRequestVideo({String? userPrompt}) async {
    if (_isLoading || _isImageLoading || _isVideoLoading) return;

    setState(() {
      _messages.add(AiChatMessage(
        role: 'user',
        content: userPrompt?.isNotEmpty == true ? userPrompt! : 'Send me a video of you 🎬',
        createdAt: DateTime.now(),
      ));
      _isVideoLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final videoUrl = await ref.read(aiChatRepositoryProvider).requestVideo(
        aiProfileId: widget.aiProfile.id,
        userPrompt: userPrompt,
      );

      if (mounted) {
        setState(() {
          _messages.add(AiChatMessage(
            role: 'video',
            content: '🎬 Here you go!',
            createdAt: DateTime.now(),
            isVideo: true,
            videoUrl: videoUrl,
          ));
          _isVideoLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint('AI Chat Request Video Error: $e');
      if (mounted) {
        final rawError = e.toString().replaceAll('Exception: ', '').toLowerCase();
        final String friendlyError;

        if (rawError.contains('insufficient coins') || rawError.contains('402')) {
          friendlyError =
              'You need more coins to request a video (150 coins). Top up and try again! 💰';
        } else if (rawError.contains('unavailable') || rawError.contains('502')) {
          friendlyError =
              '${widget.aiProfile.name} couldn\'t send a video right now. Try again! 🎬';
        } else {
          friendlyError =
              '${widget.aiProfile.name} couldn\'t send a video. Try again! 🎬';
        }

        setState(() {
          _isVideoLoading = false;
          _errorMessage = friendlyError;
        });

        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    }
  }

  /// Request a photo from the AI companion.
  Future<void> _handleRequestImage({String? userPrompt}) async {
    if (_isLoading || _isImageLoading) return;

    // Add a user-side "send photo" request message
    setState(() {
      _messages.add(AiChatMessage(
        role: 'user',
        content: userPrompt?.isNotEmpty == true ? userPrompt! : 'Send me a photo of you \ud83d\udcf8',
        createdAt: DateTime.now(),
      ));
      _isImageLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final imageUrl = await ref.read(aiChatRepositoryProvider).requestImage(
        aiProfileId: widget.aiProfile.id,
        userPrompt: userPrompt,
      );

      if (mounted) {
        setState(() {
          _messages.add(AiChatMessage(
            role: 'image',
            content: '\ud83d\udcf8 Here you go!',
            createdAt: DateTime.now(),
            isImage: true,
            imageUrl: imageUrl,
          ));
          _isImageLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      debugPrint('AI Chat Request Image Error: $e');
      if (mounted) {
        final rawError = e.toString().replaceAll('Exception: ', '').toLowerCase();
        final String friendlyError;

        if (rawError.contains('insufficient coins') || rawError.contains('402')) {
          friendlyError =
              'You need more coins to request a photo (50 coins). Top up and try again! 💰';
        } else if (rawError.contains('unavailable') || rawError.contains('502')) {
          friendlyError =
              '${widget.aiProfile.name} couldn\'t send a photo. Try again! 📸';
        } else {
          friendlyError =
              '${widget.aiProfile.name} couldn\'t send a photo. Try again! 📸';
        }

        setState(() {
          _isImageLoading = false;
          _errorMessage = friendlyError;
        });

        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  backgroundImage: widget.aiProfile.avatarUrl.isNotEmpty
                      ? NetworkImage(
                          ImageUtils.postImageUrl(widget.aiProfile.avatarUrl))
                      : null,
                  child: widget.aiProfile.avatarUrl.isEmpty
                      ? const Icon(Icons.smart_toy_rounded,
                          color: Color(0xFF8B5CF6), size: 20)
                      : null,
                ),
                // AI indicator dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome,
                          size: 7, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.aiProfile.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'AI Companion • Always online',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
        ),
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      reverse: true,
                      // Slots (bottom→top in reversed list):
                      //   0          : bottom padding (always)
                      //   1          : typing indicator (when _isLoading)
                      //   1 or 2     : error bubble (when _errorMessage != null)
                      //   remaining  : messages newest→oldest
                      itemCount: 1 +
                          ((_isLoading || _isImageLoading || _isVideoLoading) ? 1 : 0) +
                          (_errorMessage != null ? 1 : 0) +
                          _messages.length,
                      itemBuilder: (context, index) {
                        // Slot 0 — bottom padding
                        if (index == 0) return const SizedBox(height: 16);

                        int slot = 1;

                        // Slot 1 — typing, image-loading, or video-loading indicator
                        if (_isLoading || _isImageLoading || _isVideoLoading) {
                          if (index == slot) return _buildTypingIndicator(isImage: _isImageLoading, isVideo: _isVideoLoading);
                          slot++;
                        }

                        // Next slot — error bubble (only when present)
                        if (_errorMessage != null) {
                          if (index == slot) return _buildErrorBubble(_errorMessage!);
                          slot++;
                        }

                        // Remaining slots — messages, newest first
                        final msgIdx = _messages.length - (index - slot) - 1;
                        if (msgIdx < 0 || msgIdx >= _messages.length) {
                          return const SizedBox.shrink();
                        }
                        return _buildMessageBubble(_messages[msgIdx]);
                      },
                    ),
            ),

            // Input field
            _buildInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9A56).withValues(alpha: 0.15),
                    const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 40, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 20),
            Text(
              'Say hello to ${widget.aiProfile.name}! 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.aiProfile.bio.isNotEmpty
                  ? widget.aiProfile.bio
                  : 'Start a conversation and get to know each other!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Suggested messages
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestedChip(
                  text: 'Hey there! 😊',
                  onTap: () {
                    _textController.text = 'Hey there! 😊';
                    _handleSendMessage();
                  },
                ),
                _SuggestedChip(
                  text: 'Tell me about yourself',
                  onTap: () {
                    _textController.text = 'Tell me about yourself';
                    _handleSendMessage();
                  },
                ),
                _SuggestedChip(
                  text: 'What do you like?',
                  onTap: () {
                    _textController.text = 'What do you like?';
                    _handleSendMessage();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message) {
    // Delegate image messages to dedicated image bubble
    if (message.isImage && message.imageUrl != null) {
      return _buildImageBubble(message.imageUrl!);
    }

    // Delegate video messages to dedicated video bubble
    if (message.isVideo && message.videoUrl != null) {
      return _buildVideoBubble(message.videoUrl!);
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 60 : 12,
          right: isUser ? 12 : 60,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// A friendly in-chat error system bubble shown when the AI fails to respond.
  Widget _buildErrorBubble(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFCDD5), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0E6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFE05C78),
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFB03050),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI image message bubble — shows the image with a tap-to-expand viewer.
  Widget _buildImageBubble(String imageUrl) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 60, top: 6, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Image.network(
                  imageUrl,
                  width: 220,
                  height: 260,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 220,
                      height: 260,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF8B5CF6),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 12),
                          const Text('Loading photo...', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 220,
                    height: 100,
                    color: Colors.grey.shade100,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                        SizedBox(height: 8),
                        Text('Failed to load photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view full size',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline video bubble with play/pause and a fullscreen viewer.
  Widget _buildVideoBubble(String videoUrl) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 60, top: 6, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: _VideoPlayerBubble(videoUrl: videoUrl),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to play · Tap icon for full screen',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator({bool isImage = false, bool isVideo = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 60, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isVideo
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded, size: 14, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  const Text(
                    'Filming a video...',
                    style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 13),
                  ),
                ],
              )
            : isImage
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  const Text(
                    'Taking a photo...',
                    style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 13),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDot(delay: 0),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 150),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 300),
                ],
              ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          // 🎬 Video request button
          Tooltip(
            message: 'Request a video (150 coins)',
            child: GestureDetector(
              onTap: (_isLoading || _isImageLoading || _isVideoLoading)
                  ? null
                  : () => _showVideoConfirmation(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: (_isLoading || _isImageLoading || _isVideoLoading)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        ),
                  color: (_isLoading || _isImageLoading || _isVideoLoading)
                      ? Colors.grey.shade300
                      : null,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 📸 Photo request button
          Tooltip(
            message: 'Request a photo (50 coins)',
            child: GestureDetector(
              onTap: (_isLoading || _isImageLoading || _isVideoLoading)
                  ? null
                  : _handleRequestImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: (_isLoading || _isImageLoading || _isVideoLoading)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                        ),
                  color: (_isLoading || _isImageLoading || _isVideoLoading)
                      ? Colors.grey.shade300
                      : null,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // ✉️ Send message button
          GestureDetector(
            onTap: (_isLoading || _isImageLoading || _isVideoLoading) ? null : _handleSendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: (_isLoading || _isImageLoading || _isVideoLoading)
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF9A56), Color(0xFFFF6B6B)],
                      ),
                color: (_isLoading || _isImageLoading || _isVideoLoading) ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggested conversation starter chip.
class _SuggestedChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestedChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8B5CF6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Animated typing dot for the "AI is typing..." indicator.
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Inline video player bubble — plays a video URL with tap-to-play and fullscreen.
class _VideoPlayerBubble extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerBubble({required this.videoUrl});

  @override
  State<_VideoPlayerBubble> createState() => _VideoPlayerBubbleState();
}

class _VideoPlayerBubbleState extends State<_VideoPlayerBubble> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _showControls = true);
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      // Auto-hide controls after 2s while playing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _openFullscreen() {
    _controller.pause();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF8B5CF6),
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    const double bubbleWidth = 220.0;
    const double bubbleHeight = 280.0;

    if (!_initialized) {
      return Container(
        width: bubbleWidth,
        height: bubbleHeight,
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading video...',
                  style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: SizedBox(
        width: bubbleWidth,
        height: bubbleHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video frame — cover fit
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            // Progress bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF8B5CF6),
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            // Play / Pause overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            // Fullscreen button top-right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _openFullscreen,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
