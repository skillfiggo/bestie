import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/calling/services/agora_service.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String channelId; // Using chat_id as channel_id
  final String otherUserId; // Receiver ID
  final bool isVideo;
  final bool isInitiator; // True if this user started the call
  final String? callHistoryId; // For receiver to listen to same record

  const CallScreen({
    super.key,
    required this.channelId,
    required this.otherUserId,
    this.isVideo = true,
    this.isInitiator = false,
    this.callHistoryId, // Optional, provided to receiver
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  ProfileModel? _otherUserProfile;
  
  late AgoraService _agoraService;
  Timer? _timer;
  int _callDuration = 0;
  String _callHistoryId = '';
  
  // Chat overlay state
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _recentMessages = [];
  StreamSubscription? _messageSubscription;
  
  // Realtime channel for call signaling
  RealtimeChannel? _callChannel;
  bool _isEndingCall = false; // Prevent duplicate call end triggers

  @override
  void initState() {
    super.initState();
    _loadOtherUserProfile();
    _initAgora();
    _startTimer();
    _listenToMessages();
    // Note: _setupCallStatusListener is called after we get the call history ID in _initAgora
  }

  Future<void> _loadOtherUserProfile() async {
    final profile = await ref.read(profileRepositoryProvider).getProfileById(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUserProfile = profile;
      });
    }
  }

  Future<void> _initAgora() async {
    // 0. Initialize Call History ID IMMEDIATELY
    if (widget.callHistoryId != null && widget.callHistoryId!.isNotEmpty) {
      _callHistoryId = widget.callHistoryId!;
    }

    _agoraService = ref.read(agoraServiceProvider);
    
    // Setup listeners
    _agoraService.onUserJoined = (uid) {
      if (mounted) {
        setState(() {
          _remoteUid = uid;
        });
      }
    };

    _agoraService.onUserOffline = (uid) {
      if (mounted) {
        setState(() {
          _remoteUid = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended by other user'),
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _leaveCall();
          }
        });
      }
    };

    // 1. SETUP LISTENER EARLY (Critical Fix)
    // If we are the receiver (have ID), listen BEFORE asking for permissions.
    if (_callHistoryId.isNotEmpty) {
      await _setupCallStatusListener();
    }

    // 2. Initialize Agora (Ask for permissions)
    // This blocks while user grants permissions
    await _agoraService.initialize();
    
    // Join channel
    if (widget.isVideo) {
      await _agoraService.setVideoEnabled(true);
    } else {
      await _agoraService.setVideoEnabled(false);
    }

    await _agoraService.joinChannel(
      channelId: widget.channelId,
      token: '', 
      uid: 0,
    );
    
    setState(() {
      _localUserJoined = true; 
    });

    // 3. Create Call Record if Initiator (and didn't have one)
    final user = ref.read(authRepositoryProvider).getCurrentUser();
    if (user != null && widget.isInitiator && _callHistoryId.isEmpty) {
        // Fallback: Initiator creates new call_history record if not pre-created
        print('📞 Initiator creating call history record (Fallback)');
        _callHistoryId = await ref.read(callRepositoryProvider).startCall(
          channelId: widget.channelId,
          callerId: user.id,
          receiverId: widget.otherUserId,
          mediaType: widget.isVideo ? 'video' : 'voice',
        );
        print('📞 Created call_history_id: $_callHistoryId');
        
        // Setup listener NOW that we have ID
        await _setupCallStatusListener();
    }
  }

  Future<void> _setupCallStatusListener() async {
    try {
      print('📡 Setting up call status listener for: $_callHistoryId');
      final callRepo = ref.read(callRepositoryProvider);
      
      _callChannel = await callRepo.setupCallStatusListener(
        callHistoryId: _callHistoryId,
        onCallEnded: () {
          if (mounted) {
            _handleRemoteCallEnd();
          }
        },
      );
      
      print('✅ Successfully set up call status listener');
      
      // Check if call is ALREADY ended (Race condition fix)
      // If the other user ended the call while we were connecting, we might have missed the event.
      final currentStatus = await callRepo.getCallStatus(_callHistoryId);
      print('🔍 Current call status from DB: $currentStatus');
      
      if (currentStatus != null && {'ended', 'completed', 'rejected', 'canceled', 'timeout'}.contains(currentStatus)) {
        print('⚠️ Call already ended/terminal ($currentStatus), leaving...');
        if (mounted) {
          _handleRemoteCallEnd();
        }
      }
    } catch (e) {
      print('❌ Error setting up call status listener: $e');
    }
  }

  void _handleRemoteCallEnd() {
    if (_isEndingCall) {
      print('⚠️ Already ending call, ignoring duplicate trigger');
      return;
    }
    
    if (!mounted) return;
    
    print('🔔 Other user ended the call');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call ended by other user'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // End the call after a brief moment
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isEndingCall) {
        _leaveCall(sendSignal: false); // Don't send signal back
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  Future<void> _leaveCall({bool sendSignal = true}) async {
    if (_isEndingCall) {
      print('⚠️ Already ending call, ignoring duplicate _leaveCall');
      return;
    }
    
    _isEndingCall = true;
    print('🔴 _leaveCall called (sendSignal: $sendSignal)');
    
    try {
      print('🔴 Cancelling timer');
      _timer?.cancel();
      
      // Capture values before navigation/unmount
      final historyId = _callHistoryId;
      final duration = _callDuration;
      final channel = _callChannel;
      final callRepo = ref.read(callRepositoryProvider);
      
      // Navigate back IMMEDIATELY
      print('🔴 Navigating back immediately');
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Background Cleanup (Fire and Forget)
      _performBackgroundCleanup(historyId, duration, channel, callRepo);

    } catch (e) {
      print('🔴 Error in _leaveCall: $e');
      // Ensure we navigate back even if there's an error
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Helper for background cleanup so it doesn't block UI
  Future<void> _performBackgroundCleanup(
    String historyId, 
    int duration, 
    RealtimeChannel? channel,
    CallRepository callRepo,
  ) async {
    print('🧹 Starting background cleanup...');
    try {
      // 1. Log End in Database
      if (historyId.isNotEmpty) {
         await callRepo.endCall(historyId, duration).catchError((e) {
           print('🔴 Error ending call in database (background): $e');
         });
      }
      
      // 2. Agora & Realtime Cleanup
      await Future.wait([
        _agoraService.leaveChannel().catchError((e) => print('🔴 Error leaving Agora: $e')),
        if (channel != null) 
          channel.unsubscribe().catchError((e) => print('🔴 Error unsubscribing: $e')),
      ]);
      print('✅ Background cleanup complete');
    } catch (e) {
      print('⚠️ Error during background cleanup: $e');
    }
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _agoraService.toggleMute(_isMuted);
  }

  void _onSwitchCamera() {
    _agoraService.switchCamera();
  }

  void _listenToMessages() {
    final messagesAsync = ref.read(chatMessagesProvider(widget.channelId));
    messagesAsync.whenData((messages) {
      if (mounted) {
        setState(() {
          // Keep only last 3 messages (Newest), maintain ASC order (Old->New)
          final startIndex = messages.length > 3 ? messages.length - 3 : 0;
          _recentMessages = messages.sublist(startIndex);
        });
        // Auto-scroll to bottom
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId: widget.channelId,
        content: _messageController.text.trim(),
        receiverId: widget.otherUserId,
      );
      
      _messageController.clear();
      _listenToMessages(); // Refresh messages
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _callChannel?.unsubscribe();
    _agoraService.leaveChannel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildWaitingScreen() {
    final isConnected = _remoteUid != null;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
            ),
            child: ClipOval(
              child: _otherUserProfile?.avatarUrl.isNotEmpty == true
                  ? Image.network(
                      _otherUserProfile!.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Name and Age
          if (_otherUserProfile != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_otherUserProfile!.name}, ${_otherUserProfile!.age}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_otherUserProfile!.isVerified) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.verified,
                    color: Colors.blue,
                    size: 24,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ] else ...[
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
          ],
          
          // Status Text
          Text(
            isConnected ? _formatDuration(_callDuration) : 'Calling',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isConnected ? 24 : 18,
              fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          
          // Calling animation (Only if not connected)
          if (!isConnected) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: (value + index * 0.3) % 1.0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = 60,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // 1. Remote View (Full Screen)
          // Show remote video only if isVideo is true AND we have a remote UID
          Builder(builder: (context) {
             print('Debug Build: remoteUid=$_remoteUid, isVideo=${widget.isVideo}, localJoined=$_localUserJoined');
             return const SizedBox.shrink(); 
          }),
          if (_remoteUid != null && widget.isVideo)
            Positioned.fill(
              child: _agoraService.buildRemoteView(_remoteUid!, widget.channelId),
            )
          else
            _buildWaitingScreen(),

          // 2. Local View (Small box)
          if (_localUserJoined && widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _agoraService.buildLocalView(widget.channelId),
              ),
            ),

          // 3. Controls Overlay
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Call Duration - Commented out for now
                /*
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                */
                const SizedBox(height: 32),
                
                // Control Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mute/Unmute Button
                      _buildCallButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        onPressed: _onToggleMute,
                        backgroundColor: _isMuted 
                            ? AppColors.error 
                            : Colors.white.withOpacity(0.25),
                        iconColor: Colors.white,
                        size: 60,
                      ),
                      
                      // End Call Button (Larger)
                      _buildCallButton(
                        icon: Icons.call_end_rounded,
                        onPressed: () {
                          print('🔴 End call button pressed');
                          _leaveCall();
                        },
                        backgroundColor: AppColors.error,
                        iconColor: Colors.white,
                        size: 70,
                      ),
                      
                      // Switch Camera Button (Only for video calls)
                      if (widget.isVideo)
                        _buildCallButton(
                          icon: Icons.cameraswitch_rounded,
                          onPressed: _onSwitchCamera,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          iconColor: Colors.white,
                          size: 60,
                        ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),

          // 4. Chat Messages Overlay (Bottom Left)
          Positioned(
            left: 20,
            bottom: 140,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 300,
                maxHeight: 200,
              ),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: _recentMessages.length,
                itemBuilder: (context, index) {
                  final message = _recentMessages[index];
                  final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
                  final isMe = message.senderId == currentUser?.id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe 
                              ? AppColors.primary.withOpacity(0.9)
                              : Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 5. Message Input Field (Bottom)
          Positioned(
            left: 20,
            right: 20,
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
