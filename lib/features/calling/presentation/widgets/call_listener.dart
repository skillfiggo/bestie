import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';

class CallListener extends ConsumerStatefulWidget {
  final Widget child;
  const CallListener({super.key, required this.child});

  @override
  ConsumerState<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends ConsumerState<CallListener> {
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  bool _isStreamInitialized = false;
  final Set<String> _handledMessageIds = {}; // Track handled call messages

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      // Listen to messages where receiver_id is ME
      // Note: Supabase Realtime 'postgres_changes' is better for this
      // strict 'INSERT' listening.
      
      SupabaseService.client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: user.id,
            ),
            callback: (payload) {
               _handleNewMessage(payload.newRecord);
            },
          )
          .subscribe();
      
      _isStreamInitialized = true;
    }
  }

  void _handleNewMessage(Map<String, dynamic> record) async {
    // Check if it's a call start message
    final content = record['content'] as String? ?? '';
    final chatId = record['chat_id'] as String;
    final senderId = record['sender_id'] as String;
    final messageId = record['id'] as String;
    
    bool isVideo = content.toLowerCase().contains('video call');
    bool isCall = content.contains('Started a');

    if (isCall) {
      // Check if we've already handled this message
      if (_handledMessageIds.contains(messageId)) {
        print('Call message already handled: $messageId');
        return;
      }
      
      // Extract call_history_id from message content
      String? callHistoryId;
      final callIdMatch = RegExp(r'\[call_id:([^\]]+)\]').firstMatch(content);
      if (callIdMatch != null) {
        callHistoryId = callIdMatch.group(1);
        print('📞 Extracted call_history_id: $callHistoryId');
      }
      
      // Mark this message as handled
      _handledMessageIds.add(messageId);
      
      if (!mounted) return;
      
      // Fetch caller's profile
      final callerProfile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', senderId)
          .single();
      
      final callerName = callerProfile['name'] as String? ?? 'Unknown';
      final callerAge = callerProfile['age'] as int? ?? 0;
      final callerGender = callerProfile['gender'] as String? ?? '';
      final callerAvatar = callerProfile['avatar_url'] as String? ?? '';
      final isVerified = callerProfile['is_verified'] as bool? ?? false;
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Caller Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 3),
                ),
                child: ClipOval(
                  child: callerAvatar.isNotEmpty
                      ? Image.network(
                          callerAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade300,
                              child: Icon(
                                callerGender.toLowerCase() == 'female'
                                    ? Icons.female
                                    : Icons.male,
                                size: 50,
                                color: callerGender.toLowerCase() == 'female'
                                    ? Colors.pink
                                    : Colors.blue,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: Icon(
                            callerGender.toLowerCase() == 'female'
                                ? Icons.female
                                : Icons.male,
                            size: 50,
                            color: callerGender.toLowerCase() == 'female'
                                ? Colors.pink
                                : Colors.blue,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Caller Name and Age
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$callerName, $callerAge',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.blue, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // Call Type
              Text(
                isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        // Notify database about rejection
                        if (callHistoryId != null) {
                           ref.read(callRepositoryProvider).rejectCall(callHistoryId);
                        }
                        Navigator.pop(context); // Close dialog
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Request permissions first
                        final micPermission = await Permission.microphone.request();
                        PermissionStatus? cameraPermission;
                        
                        if (isVideo) {
                          cameraPermission = await Permission.camera.request();
                        }

                        // Check if permissions granted
                        final micGranted = micPermission.isGranted;
                        final cameraGranted = isVideo ? (cameraPermission?.isGranted ?? false) : true;

                        if (!micGranted || !cameraGranted) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  !micGranted
                                      ? 'Microphone permission is required for calls'
                                      : 'Camera permission is required for video calls',
                                ),
                                action: SnackBarAction(
                                  label: 'Settings',
                                  onPressed: () => openAppSettings(),
                                ),
                              ),
                            );
                          }
                          return; // Don't match/navigate if denied
                        }

                        if (context.mounted) {
                          Navigator.pop(context); // Close dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallScreen(
                                channelId: chatId,
                                otherUserId: senderId,
                                isVideo: isVideo,
                                isInitiator: false,
                                callHistoryId: callHistoryId,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_isStreamInitialized) {
      SupabaseService.client.channel('public:messages').unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
