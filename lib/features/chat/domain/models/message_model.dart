

enum MessageType {
  text,
  image,
  voice,
  video,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDuration; // in seconds
  final bool isMe;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    required this.isMe,
  });

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? imageUrl,
    String? voiceUrl,
    int? voiceDuration,
    bool? isMe,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      isMe: isMe ?? this.isMe,
    );
  }
}

class MockMessages {
  static List<MessageModel> getMessages(String chatId) {
    final now = DateTime.now();
    
    return [
      MessageModel(
        id: '1',
        senderId: chatId,
        receiverId: 'me',
        content: 'Hey! How are you doing?',
        timestamp: now.subtract(const Duration(hours: 2)),
        isMe: false,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '2',
        senderId: 'me',
        receiverId: chatId,
        content: 'I\'m doing great! Thanks for asking 😊',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 58)),
        isMe: true,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '3',
        senderId: 'me',
        receiverId: chatId,
        content: 'How about you?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 57)),
        isMe: true,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '4',
        senderId: chatId,
        receiverId: 'me',
        content: 'Pretty good! Just finished work. Want to grab coffee later?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
        isMe: false,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '5',
        senderId: 'me',
        receiverId: chatId,
        content: 'That sounds perfect! What time works for you?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
        isMe: true,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '6',
        senderId: chatId,
        receiverId: 'me',
        content: 'How about 5 PM at the usual place?',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 15)),
        isMe: false,
        status: MessageStatus.read,
      ),
      MessageModel(
        id: '7',
        senderId: 'me',
        receiverId: chatId,
        content: 'Perfect! See you there! 👍',
        timestamp: now.subtract(const Duration(minutes: 45)),
        isMe: true,
        status: MessageStatus.delivered,
      ),
      MessageModel(
        id: '8',
        senderId: chatId,
        receiverId: 'me',
        content: 'Great! Looking forward to it 😊',
        timestamp: now.subtract(const Duration(minutes: 30)),
        isMe: false,
        status: MessageStatus.sent,
      ),
    ];
  }
}
