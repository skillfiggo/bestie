class Moment {
  final String id;
  final String userId;
  final String userName;
  final int userAge;
  final String userImage;
  final String content;
  final String? imageUrl;
  final int likes;
  final int comments;
  final bool isLiked;
  final DateTime createdAt;

  const Moment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAge,
    required this.userImage,
    required this.content,
    this.imageUrl,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  factory Moment.fromMap(Map<String, dynamic> map, {bool isLiked = false}) {
    final profile = map['profiles'];
    return Moment(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: profile?['name'] ?? 'Unknown',
      userAge: profile?['age'] ?? 0,
      userImage: profile?['avatar_url'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['image_url'],
      likes: map['likes_count'] ?? 0,
      comments: map['comments_count'] ?? 0,
      isLiked: isLiked,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Moment copyWith({
    String? id,
    String? userId,
    String? userName,
    int? userAge,
    String? userImage,
    String? content,
    String? imageUrl,
    int? likes,
    int? comments,
    bool? isLiked,
    DateTime? createdAt,
  }) {
    return Moment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAge: userAge ?? this.userAge,
      userImage: userImage ?? this.userImage,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      // 'created_at': createdAt.toIso8601String(), // Let DB handle creation time
    };
  }
  
  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

