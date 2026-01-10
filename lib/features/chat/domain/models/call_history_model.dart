enum CallType {
  incoming,
  outgoing,
  missed,
}

enum CallMediaType {
  voice,
  video,
}

class CallHistoryModel {
  final String id;
  final String contactId;
  final String contactName;
  final String contactImageUrl;
  final CallType callType;
  final CallMediaType mediaType;
  final DateTime timestamp;
  final int durationSeconds; // 0 for missed calls
  final bool isOnline;
  final bool showOnlineStatus;

  const CallHistoryModel({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.contactImageUrl,
    required this.callType,
    required this.mediaType,
    required this.timestamp,
    this.durationSeconds = 0,
    this.isOnline = false,
    this.showOnlineStatus = true,
  });

  String get formattedDuration {
    if (durationSeconds == 0) return 'Missed';
    
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    
    if (minutes == 0) {
      return '${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  factory CallHistoryModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    final callerId = map['caller_id'] as String;
    final receiverId = map['receiver_id'] as String;
    
    // Determine if this is incoming or outgoing based on current user
    final isCurrentUserCaller = callerId == currentUserId;
    final otherUserId = isCurrentUserCaller ? receiverId : callerId;
    
    // Get the other user's profile data
    final otherProfile = isCurrentUserCaller 
        ? map['receiver_profile'] 
        : map['caller_profile'];
    
    // Determine call type from database or infer from caller/receiver
    CallType callType;
    final dbCallType = map['call_type'] as String?;
    
    if (dbCallType == 'missed') {
      callType = CallType.missed;
    } else if (isCurrentUserCaller) {
      callType = CallType.outgoing;
    } else {
      callType = CallType.incoming;
    }
    
    return CallHistoryModel(
      id: map['id'] as String,
      contactId: otherUserId,
      contactName: otherProfile?['name'] ?? 'Unknown',
      contactImageUrl: otherProfile?['avatar_url'] ?? '',
      callType: callType,
      mediaType: map['media_type'] == 'video' 
          ? CallMediaType.video 
          : CallMediaType.voice,
      timestamp: DateTime.parse(map['created_at'] as String),
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      isOnline: otherProfile?['is_online'] ?? false,
      showOnlineStatus: otherProfile?['show_online_status'] ?? true,
    );
  }
}

class MockCallHistory {
  static List<CallHistoryModel> getCallHistory() {
    final now = DateTime.now();
    
    return [
      CallHistoryModel(
        id: '1',
        contactId: '1',
        contactName: 'Sarah',
        contactImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        callType: CallType.incoming,
        mediaType: CallMediaType.video,
        timestamp: now.subtract(const Duration(hours: 2)),
        durationSeconds: 1245, // 20m 45s
        isOnline: true,
      ),
      CallHistoryModel(
        id: '2',
        contactId: '2',
        contactName: 'Emily',
        contactImageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        callType: CallType.outgoing,
        mediaType: CallMediaType.voice,
        timestamp: now.subtract(const Duration(hours: 5)),
        durationSeconds: 420, // 7m 0s
        isOnline: false,
      ),
      CallHistoryModel(
        id: '3',
        contactId: '3',
        contactName: 'Jessica',
        contactImageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        callType: CallType.missed,
        mediaType: CallMediaType.video,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        durationSeconds: 0,
        isOnline: true,
      ),
      CallHistoryModel(
        id: '4',
        contactId: '4',
        contactName: 'James',
        contactImageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
        callType: CallType.outgoing,
        mediaType: CallMediaType.voice,
        timestamp: now.subtract(const Duration(days: 1, hours: 8)),
        durationSeconds: 180, // 3m 0s
        isOnline: false,
      ),
      CallHistoryModel(
        id: '5',
        contactId: '5',
        contactName: 'Michael',
        contactImageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
        callType: CallType.incoming,
        mediaType: CallMediaType.video,
        timestamp: now.subtract(const Duration(days: 2)),
        durationSeconds: 2100, // 35m 0s
        isOnline: true,
      ),
      CallHistoryModel(
        id: '6',
        contactId: '1',
        contactName: 'Sarah',
        contactImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        callType: CallType.missed,
        mediaType: CallMediaType.voice,
        timestamp: now.subtract(const Duration(days: 3)),
        durationSeconds: 0,
        isOnline: true,
      ),
      CallHistoryModel(
        id: '7',
        contactId: '2',
        contactName: 'Emily',
        contactImageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        callType: CallType.outgoing,
        mediaType: CallMediaType.video,
        timestamp: now.subtract(const Duration(days: 4)),
        durationSeconds: 900, // 15m 0s
        isOnline: false,
      ),
      CallHistoryModel(
        id: '8',
        contactId: '3',
        contactName: 'Jessica',
        contactImageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        callType: CallType.incoming,
        mediaType: CallMediaType.voice,
        timestamp: now.subtract(const Duration(days: 5)),
        durationSeconds: 540, // 9m 0s
        isOnline: true,
      ),
    ];
  }
}
