import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/calling/services/agora_service.dart';
import 'package:bestie/features/calling/data/repositories/agora_token_repository.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:bestie/core/services/audio_service.dart';

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
  ProfileModel? _otherUserProfile;
  ProfileModel? _currentUserProfile;
  
  late AgoraService _agoraService;
  Timer? _timer;
  int _callDuration = 0;
  int _connectedSeconds = 0; // Track duration for billing
  String _callHistoryId = '';
  
  // Call signaling state
  RealtimeChannel? _callChannel;
  bool _isEndingCall = false; // Prevent duplicate call end triggers
  Timer? _tokenRefreshTimer;
  String? _errorMessage;

  // In-call messaging state
  final List<Map<String, String>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _secureScreen(); // Prevent screenshots
    _loadProfiles();
    _initAgora();
    _startTimer();
    // Note: _setupCallStatusListener is called after we get the call history ID in _initAgora
  }

  Future<void> _loadProfiles() async {
    final other = await ref.read(profileRepositoryProvider).getProfileById(widget.otherUserId);
    final user = ref.read(authRepositoryProvider).getCurrentUser();
    ProfileModel? current;
    if (user != null) {
      current = await ref.read(profileRepositoryProvider).getProfileById(user.id);
    }

    if (mounted) {
      setState(() {
        _otherUserProfile = other;
        _currentUserProfile = current;
      });
    }
  }

  Future<void> _initAgora() async {
    try {
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
          // Stop ringing when someone joins
          ref.read(audioServiceProvider).stop();
          // Reset timer to 0 when user joins (actual call start)
          _callDuration = 0;
        }
      };

      _agoraService.onUserOffline = (uid) {
        if (mounted) {
          setState(() {
            _remoteUid = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call ended by other user')),
          );
          // Stop ringing if call ends
          ref.read(audioServiceProvider).stop();
          _leaveCall();
        }
      };

      // 1. SETUP LISTENER EARLY
      if (_callHistoryId.isNotEmpty) {
        await _setupCallStatusListener();
      }

      // 2. Initialize Agora
      await _agoraService.initialize();
      
      // 3. Fetch Initial Token
      await _fetchAndUpdateToken();
      
      // 4. Create Call Record if Initiator
      final user = ref.read(authRepositoryProvider).getCurrentUser();
      if (user != null && widget.isInitiator && _callHistoryId.isEmpty) {
          _callHistoryId = await ref.read(callRepositoryProvider).startCall(
            channelId: widget.channelId,
            callerId: user.id,
            receiverId: widget.otherUserId,
            mediaType: widget.isVideo ? 'video' : 'voice',
          );
          await _setupCallStatusListener();
      }

      // 5. Start Outgoing Ringtone if Initiator
      if (widget.isInitiator && _remoteUid == null && mounted) {
        ref.read(audioServiceProvider).playOutgoingRingtone();
      }
    } catch (e) {
      debugPrint('❌ Call initialization failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _secureScreen() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint('Failed to secure screen: $e');
    }
  }

  Future<void> _unsecureScreen() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('Failed to unsecure screen: $e');
    }
  }

  Future<void> _fetchAndUpdateToken() async {
    try {
      debugPrint('🔑 Fetching Agora token...');
      final tokenResponse = await ref.read(agoraTokenRepositoryProvider).getToken(
        channelName: widget.channelId,
        uid: 0,
      );
      
      if (!_localUserJoined) {
        // Initial Join
        if (widget.isVideo) {
          await _agoraService.setVideoEnabled(true);
        } else {
          await _agoraService.setVideoEnabled(false);
        }

        await _agoraService.joinChannel(
          channelId: widget.channelId,
          token: tokenResponse.token,
          uid: tokenResponse.uid,
        );
        
        if (mounted) {
          setState(() {
            _localUserJoined = true; 
          });
        }
      } else {
        // Renewal
        await _agoraService.renewToken(tokenResponse.token);
      }

      // Schedule next refresh (Refresh 10 minutes before 1-hour expiry)
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = Timer(const Duration(minutes: 50), () {
        if (mounted && !_isEndingCall) {
          _fetchAndUpdateToken();
        }
      });
      
    } catch (e) {
      debugPrint('❌ Error fetching/updating token: $e');
      if (!_localUserJoined && mounted) {
        setState(() {
          _errorMessage = "Failed to connect to call service. Please try again.";
        });
      }
    }
  }

  Future<void> _setupCallStatusListener() async {
    try {
      debugPrint('📡 Setting up call status listener for: $_callHistoryId');
      final callRepo = ref.read(callRepositoryProvider);
      
      _callChannel = await callRepo.setupCallStatusListener(
        callHistoryId: _callHistoryId,
        onCallEnded: () {
          if (mounted) {
            _handleRemoteCallEnd();
          }
        },
      );

      // Listen for in-call messages
      _callChannel?.onBroadcast(
        event: 'message',
        callback: (payload) {
          debugPrint('📥 Received broadcast message: $payload');
          if (mounted) {
            final senderName = payload['sender_name'] as String? ?? 'User';
            final text = payload['text'] as String? ?? '';
            debugPrint('📥 Parsed - Sender: $senderName, Text: $text');
            _addMessage(senderName, text);
          }
        },
      );
      
      debugPrint('✅ Successfully set up call status listener');
      
      // Check if call is ALREADY ended (Race condition fix)
      // If the other user ended the call while we were connecting, we might have missed the event.
      final currentStatus = await callRepo.getCallStatus(_callHistoryId);
      debugPrint('🔍 Current call status from DB: $currentStatus');
      
      if (currentStatus != null && {'ended', 'completed', 'rejected', 'canceled', 'timeout'}.contains(currentStatus)) {
        debugPrint('⚠️ Call already ended/terminal ($currentStatus), leaving...');
        if (mounted) {
          _handleRemoteCallEnd();
        }
      }
    } catch (e) {
      debugPrint('❌ Error setting up call status listener: $e');
    }
  }

  void _addMessage(String senderName, String text) {
    debugPrint('📨 Adding message - Sender: $senderName, Text: $text');
    setState(() {
      _messages.add({
        'sender': senderName,
        'text': text,
      });
      // Keep only last 6 messages to avoid clutter
      if (_messages.length > 6) {
        _messages.removeAt(0);
      }
    });
    debugPrint('📨 Messages list now has ${_messages.length} messages');
    
    // Auto-remove message after 15 seconds (disappearing effect)
    Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['text'] == text && m['sender'] == senderName);
        });
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
    final userName = currentUser?.email?.split('@')[0] ?? 'Me';
    
    debugPrint('📤 Sending message - User: $userName, Text: $text');
    debugPrint('📤 Channel available: ${_callChannel != null}');
    
    // 1. Send via Broadcast using Supabase Realtime
    _callChannel?.sendBroadcastMessage(
      event: 'message',
      payload: {
        'sender_name': userName,
        'text': text,
      },
    ).then((response) {
      debugPrint('📤 Broadcast sent successfully: $response');
    }).catchError((error) {
      debugPrint('❌ Error sending broadcast: $error');
    });

    // 2. Add to local list
    _addMessage('Me', text);
    
    // 3. Clear controller
    _messageController.clear();
    _messageFocusNode.unfocus();
  }

  void _handleRemoteCallEnd() {
    if (_isEndingCall) {
      debugPrint('⚠️ Already ending call, ignoring duplicate trigger');
      return;
    }
    if (!mounted) return;
    
    debugPrint('🔔 Other user ended the call');
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

  Future<void> _deductCallCost() async {
    final cost = widget.isVideo ? 200 : 100;
    try {
      final user = ref.read(authRepositoryProvider).getCurrentUser();
      if (user == null) return;
      
      debugPrint('💰 Processing call payment: $cost coins');
      // Use the new atomic transfer method (60/40 profit split)
      await ref.read(callRepositoryProvider).processEarningTransfer(
        senderId: user.id,
        receiverId: widget.otherUserId,
        amount: cost,
        type: widget.isVideo ? 'video_call' : 'voice_call',
      );
    } catch (e) {
      debugPrint('❌ Billing failed: $e');
      if (mounted) {
        String errorMessage = 'Insufficient coins. Call ending...';
        if (e.toString().contains('Insufficient coins')) {
           errorMessage = 'Insufficient coins. Please recharge.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(errorMessage)),
        );
        // Delay slightly to let user see message
        Future.delayed(const Duration(seconds: 1), () {
           if (mounted) _leaveCall(status: 'ended');
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });

        // 25-second timeout if remote user hasn't joined (Initiator side only)
        if (widget.isInitiator && _remoteUid == null && _callDuration >= 25 && !_isEndingCall) {
          debugPrint('⏳ Call timed out after 25 seconds');
          _leaveCall(status: 'timeout');
        }

        // Billing Logic: Only Male users pay.
        // If current user is Male, he pays regardless of being initiator or receiver.
        final isPayer = _currentUserProfile?.gender == 'male';
        
        if (isPayer && _remoteUid != null) {
          if (_connectedSeconds % 60 == 0) {
            _deductCallCost();
          }
          _connectedSeconds++;
        }
      }
    });
  }

  Future<void> _leaveCall({bool sendSignal = true, String? status}) async {
    if (_isEndingCall) {
      debugPrint('⚠️ Already ending call, ignoring duplicate _leaveCall');
      return;
    }
    
    _isEndingCall = true;
    debugPrint('🔴 _leaveCall called (sendSignal: $sendSignal, status: $status)');
    
    // Determine the final status to record
    String finalStatus = status ?? 'ended';
    if (status == null && _remoteUid == null && widget.isInitiator) {
      finalStatus = 'canceled';
    }

    // Send Call Details/Missed Call Notification (Free system messages)
    if (widget.isInitiator) {
        final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
        if (currentUser != null) {
           if (_remoteUid == null) {
              // connection was never established -> Missed Call
              ref.read(callRepositoryProvider).sendMissedCallMessage(
                chatId: widget.channelId,
                senderId: currentUser.id,
                receiverId: widget.otherUserId,
                isVideo: widget.isVideo,
              );
           } else {
              // Call was successful -> Send Details
              ref.read(callRepositoryProvider).sendCallEndMessage(
                chatId: widget.channelId,
                senderId: currentUser.id,
                receiverId: widget.otherUserId,
                mediaType: widget.isVideo ? 'video' : 'voice',
                durationSeconds: _callDuration,
              );
           }
        }
    }
    
    try {
      debugPrint('🔴 Cancelling timers and stopping audio');
      _timer?.cancel();
      ref.read(audioServiceProvider).stop();
      _tokenRefreshTimer?.cancel();
      
      // Capture values before navigation/unmount
      final historyId = _callHistoryId;
      final duration = _callDuration;
      final channel = _callChannel;
      final callRepo = ref.read(callRepositoryProvider);
      
      // Navigate back IMMEDIATELY
      debugPrint('🔴 Navigating back immediately');
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Background Cleanup (Fire and Forget)
      _performBackgroundCleanup(historyId, duration, channel, callRepo, status: finalStatus);

    } catch (e) {
      debugPrint('🔴 Error in _leaveCall: $e');
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
    CallRepository callRepo, {
    String status = 'ended',
  }) async {
    debugPrint('🧹 Starting background cleanup with status: $status');
    try {
      // 1. Log End in Database
      if (historyId.isNotEmpty) {
         await callRepo.endCall(historyId, duration, status: status).catchError((e) {
           debugPrint('🔴 Error ending call in database (background): $e');
         });
      }
      
      // 2. Agora & Realtime Cleanup
      await Future.wait([
        _agoraService.leaveChannel().catchError((e) { 
          debugPrint('🔴 Error leaving Agora: $e');
        }),
        if (channel != null) 
          channel.unsubscribe().catchError((e) { 
            debugPrint('🔴 Error unsubscribing: $e');
            return ''; // Expects String
          }),
      ]);
      debugPrint('✅ Background cleanup complete');
    } catch (e) {
      debugPrint('⚠️ Error during background cleanup: $e');
    }
  }

  Future<void> _showEndCallConfirmation() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('End Call', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end this call?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Call', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (result == true) {
      _leaveCall();
    }
  }



  @override
  void dispose() {
    _unsecureScreen(); // Re-enable screenshots
    _timer?.cancel();
    _tokenRefreshTimer?.cancel();
    _callChannel?.unsubscribe();
    _agoraService.leaveChannel();
    ref.read(audioServiceProvider).stop();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildWaitingScreen() {
    final isConnected = _remoteUid != null;
    
    return Stack(
      children: [
        // 1. Base Lime Background
        Positioned.fill(
          child: Container(
            color: AppColors.lime,
          ),
        ),

        // 2. Faint Background Image (Lower Opacity)
        if (_otherUserProfile?.avatarUrl.isNotEmpty == true)
          Positioned.fill(
            child: Opacity(
              opacity: 0.15, // Reduced opacity as requested
              child: Image.network(
                _otherUserProfile!.avatarUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        // 3. Vignette Overlay for Text Readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        
        // 4. Main Content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with Pulsing Animation
              Stack(
                alignment: Alignment.center,
                children: [
                  if (!isConnected)
                    const _PulsingCircles(),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _otherUserProfile?.avatarUrl.isNotEmpty == true
                          ? Image.network(
                              _otherUserProfile!.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Name and Age
              if (_otherUserProfile != null) ...[
                Column(
                  children: [
                    Text(
                      _otherUserProfile!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_otherUserProfile!.isVerified) ...[
                            const Icon(Icons.verified, color: AppColors.info, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${_otherUserProfile!.age} years old',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ] else ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 48),
              ],
              
              // Status Text
              Text(
                isConnected ? _formatDuration(_callDuration) : 'Calling...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: isConnected ? 28 : 20,
                  fontWeight: isConnected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: isConnected ? 2 : 1.5,
                  shadows: const [
                    Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.grey,
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
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 64),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool showWaitingScreen = _remoteUid == null;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote View (Full Screen)
          if (_remoteUid != null && widget.isVideo)
            Positioned.fill(
              child: _agoraService.buildRemoteView(_remoteUid!, widget.channelId),
            ),

          // 2. Waiting Screen
          if (showWaitingScreen)
            _buildWaitingScreen(),

          // 3. Local View (Small box)
          if (_localUserJoined && widget.isVideo && !showWaitingScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, // Pushed down to make room for X
              right: 20,
              width: 110,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _agoraService.buildLocalView(widget.channelId),
                ),
              ),
            ),

          // 4. Top Controls (Back button / User Name if connected)
          if (!showWaitingScreen)
             Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => _leaveCall(),
                        ),
                        if (_otherUserProfile != null)
                          Text(
                            _otherUserProfile!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                            ),
                          ),
                      ],
                    ),
                    if (_remoteUid != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: AppColors.lime, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(_callDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                // End Call Cross Button at Top Right
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: _showEndCallConfirmation,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. In-Call Messages (Bottom Left)
          if (!showWaitingScreen)
            Positioned(
              bottom: 110,
              left: 20,
              right: 140, // Avoid overlapping with main controls if any
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _messages.map((msg) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${msg['sender']}: ',
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: msg['text'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 6. Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message Input Layer
                if (!showWaitingScreen)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Send a message...',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Only show end call button during waiting screen
                if (showWaitingScreen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Center(
                      child: _buildCallButton(
                        icon: Icons.call_end_rounded,
                        onPressed: () => _leaveCall(),
                        backgroundColor: AppColors.error,
                        iconColor: Colors.white,
                        size: 72,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing Circles Animation for the waiting screen
class _PulsingCircles extends StatefulWidget {
  const _PulsingCircles();

  @override
  State<_PulsingCircles> createState() => _PulsingCirclesState();
}

class _PulsingCirclesState extends State<_PulsingCircles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final double progress = (_controller.value + index / 3) % 1.0;
            return Container(
              width: 140 + (progress * 150),
              height: 140 + (progress * 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: (1 - progress) * 0.4),
                  width: 2,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
