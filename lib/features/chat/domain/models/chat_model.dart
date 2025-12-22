class ChatModel {
  final String id;
  final String otherUserId;
  final String name;
  final String imageUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isOfficial;

  const ChatModel({
    required this.id,
    required this.otherUserId,
    required this.name,
    required this.imageUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isOfficial = false,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String currentUserId, {int unreadCount = 0}) {
    // Logic to determine other user's details assuming 'profiles' join
    final isUser1 = map['user1_id'] == currentUserId;
    final otherUser = isUser1 ? map['profile2'] : map['profile1'];

    return ChatModel(
      id: map['id'],
      otherUserId: isUser1 ? map['user2_id'] : map['user1_id'],
      name: otherUser?['name'] ?? 'Unknown',
      imageUrl: otherUser?['avatar_url'] ?? '',
      lastMessage: map['last_message'] ?? '',
      lastMessageTime: map['last_message_time'] != null 
          ? DateTime.parse(map['last_message_time'])
          : DateTime.fromMillisecondsSinceEpoch(0), // Fallback
      unreadCount: unreadCount,
      isOnline: otherUser?['is_online'] ?? false,
      isOfficial: false, // You might want to flag specific IDs as official
    );
  }
}

enum MessageType { text, image, voice, video }
enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final Duration? duration;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.status,
    this.mediaUrl,
    this.metadata,
    this.duration,
    required this.createdAt,
  });
  
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      chatId: map['chat_id'],
      senderId: map['sender_id'],
      content: map['content'],
      type: MessageType.values.firstWhere((e) => e.name == map['message_type'], orElse: () => MessageType.text),
      status: MessageStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => MessageStatus.sent),
      mediaUrl: map['media_url'],
      metadata: map['metadata'],
      duration: map['metadata'] != null && map['metadata']['duration'] != null
          ? Duration(seconds: map['metadata']['duration'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': type.name,
      'status': status.name,
      'media_url': mediaUrl,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isMe => false; // Helper, usually determined by context
}
