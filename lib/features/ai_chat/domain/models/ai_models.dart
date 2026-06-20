/// Data model for an AI companion profile.
class AiProfileModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final int age;
  final List<String> interests;
  final bool isActive;

  const AiProfileModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.age,
    required this.interests,
    required this.isActive,
  });

  factory AiProfileModel.fromMap(Map<String, dynamic> map) {
    return AiProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown',
      avatarUrl: map['avatar_url'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      age: map['age'] as int? ?? 22,
      interests: (map['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// A single message in an AI chat session (kept in-memory only).
class AiChatMessage {
  final String role; // 'user', 'assistant', 'image', or 'video'
  final String content;
  final DateTime createdAt;
  final bool isImage;        // true when the assistant sent an image
  final String? imageUrl;    // populated when isImage == true
  final bool isVideo;        // true when the assistant sent a video
  final String? videoUrl;    // populated when isVideo == true

  const AiChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.isImage = false,
    this.imageUrl,
    this.isVideo = false,
    this.videoUrl,
  });

  bool get isUser => role == 'user';

  Map<String, String> toApiMap() => {
        'role': (role == 'image' || role == 'video') ? 'assistant' : role,
        'content': content,
      };
}

