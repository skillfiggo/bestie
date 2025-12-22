import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final agoraServiceProvider = Provider((ref) => AgoraService());

class AgoraService {
  late RtcEngine _engine;
  bool _isInitialized = false;
  int _localUid = 0; // Store the local UID
  
  // Callbacks for UI to listen to
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserOffline;

  Future<void> initialize() async {
    if (_isInitialized) return;

    String appId = dotenv.env['AGORA_APP_ID'] ?? '';
    print('🔴 Debug - Loaded Agora App ID: ${appId.isEmpty ? "EMPTY" : "${appId.substring(0, 5)}..."}'); 
    if (appId.isEmpty || appId == 'YOUR_AGORA_APP_ID_HERE') {
      print('🔴 Agora App ID is missing or invalid in .env');
      if (appId.isEmpty) return;
    }

    // Request Permissions
    if (!kIsWeb) {
      await [Permission.microphone, Permission.camera].request();
    }

    // Create Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register Event Handler
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("✅ JOINED CHANNEL SUCCESS: ${connection.channelId} uid=${connection.localUid}");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("REMOTE JOINED: $remoteUid");
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print("REMOTE LEFT: $remoteUid");
          onUserOffline?.call(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          print("🔴 Agora Error: $err - $msg");
        },
      ),
    );

    await _engine.enableVideo();
    
    if (!kIsWeb) {
      await _engine.setupLocalVideo(
        const VideoCanvas(uid: 0, renderMode: RenderModeType.renderModeHidden),
      );
    }
    
    await _engine.startPreview();

    _isInitialized = true;
  }

  Future<void> joinChannel({
    required String channelId,
    required String token, // In prod, fetch from your backend
    required int uid,      // 0 for auto-assign, or specific ID
  }) async {
    print('🔴 joining channel: $channelId with uid: $uid');
    if (!_isInitialized) await initialize();
    

    // Determine local UID
    _localUid = uid;
    if (_localUid == 0) {
      _localUid = DateTime.now().millisecondsSinceEpoch.remainder(100000000);
    }

    try {
      await _engine.enableVideo();
      await _engine.enableAudio();
      await _engine.startPreview(); // Important for web

      await _engine.joinChannel(
        token: token.isEmpty ? '' : token, // Empty token works for testing if "App ID without Certificate" is enabled
        channelId: channelId,
        uid: _localUid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      print('🔴 joinChannel called successfully');
    } catch (e) {
      print('🔴 Error joining channel: $e');
    }
  }


  Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    try {
      await _engine.leaveChannel();
      await _engine.stopPreview(); // Turn off camera light
    } catch (e) {
      print('⚠️ Error leaving channel/stopping preview: $e');
    }
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> toggleMute(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }
  
  Future<void> toggleVideo(bool disabled) async {
    await _engine.muteLocalVideoStream(disabled);
  }

  Future<void> setVideoEnabled(bool enabled) async {
    if (!_isInitialized) return;
    if (enabled) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.stopPreview();
      await _engine.disableVideo();
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _engine.release();
      _isInitialized = false;
    }
  }
  
  Widget buildLocalView(String channelId) {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: kIsWeb ? _localUid : 0), // Use stored local UID for web, 0 for mobile
        // connection: RtcConnection(channelId: channelId), // Removed as it caused compilation error on this version
      ),
    );
  }

  Widget buildRemoteView(int remoteUid, String channelId) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: remoteUid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }
}
