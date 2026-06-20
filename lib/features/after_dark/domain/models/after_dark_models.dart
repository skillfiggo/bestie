/// Domain models for the After Dark feature.

// ─── Topic ───────────────────────────────────────────────────
class AfterDarkTopic {
  final String id;
  final String topic;
  final DateTime revealDate;

  const AfterDarkTopic({
    required this.id,
    required this.topic,
    required this.revealDate,
  });

  factory AfterDarkTopic.fromMap(Map<String, dynamic> m) => AfterDarkTopic(
        id:         m['id'] as String,
        topic:      m['topic'] as String,
        revealDate: DateTime.parse(m['reveal_date'] as String),
      );

  /// Returns true if this topic is today's (UTC date match).
  bool get isToday {
    final today = DateTime.now().toUtc();
    return revealDate.year == today.year &&
        revealDate.month == today.month &&
        revealDate.day == today.day;
  }
}

// ─── Story ───────────────────────────────────────────────────
class AfterDarkStory {
  final String id;
  final String userId;
  final String topicId;
  final String content;
  final bool isAnonymous;
  final String status; // 'pending' | 'approved' | 'rejected'
  final int totalDiamonds;
  final int likeCount;
  final int superLikeCount;
  final DateTime createdAt;

  // Joined from profiles (populated in feed queries)
  final String? username;
  final String? avatarUrl;

  // Joined from topics (populated in feed queries)
  final String? topicText;

  // Client-side state — set after checking reactions table
  final bool hasLiked;
  final bool hasSuperLiked;

  const AfterDarkStory({
    required this.id,
    required this.userId,
    required this.topicId,
    required this.content,
    required this.isAnonymous,
    required this.status,
    required this.totalDiamonds,
    required this.likeCount,
    required this.superLikeCount,
    required this.createdAt,
    this.username,
    this.avatarUrl,
    this.topicText,
    this.hasLiked = false,
    this.hasSuperLiked = false,
  });

  factory AfterDarkStory.fromMap(Map<String, dynamic> m) => AfterDarkStory(
        id:             m['id'] as String,
        userId:         m['user_id'] as String,
        topicId:        m['topic_id'] as String,
        content:        m['content'] as String,
        isAnonymous:    m['is_anonymous'] as bool? ?? false,
        status:         m['status'] as String? ?? 'pending',
        totalDiamonds:  m['total_diamonds'] as int? ?? 0,
        likeCount:      m['like_count'] as int? ?? 0,
        superLikeCount: m['super_like_count'] as int? ?? 0,
        createdAt:      DateTime.parse(m['created_at'] as String),
        username:       m['username'] as String?,
        avatarUrl:      m['avatar_url'] as String?,
        topicText:      m['topic'] as String?,
      );

  AfterDarkStory copyWith({
    bool? hasLiked,
    bool? hasSuperLiked,
    int? likeCount,
    int? superLikeCount,
    int? totalDiamonds,
  }) =>
      AfterDarkStory(
        id:             id,
        userId:         userId,
        topicId:        topicId,
        content:        content,
        isAnonymous:    isAnonymous,
        status:         status,
        totalDiamonds:  totalDiamonds ?? this.totalDiamonds,
        likeCount:      likeCount ?? this.likeCount,
        superLikeCount: superLikeCount ?? this.superLikeCount,
        createdAt:      createdAt,
        username:       username,
        avatarUrl:      avatarUrl,
        topicText:      topicText,
        hasLiked:       hasLiked ?? this.hasLiked,
        hasSuperLiked:  hasSuperLiked ?? this.hasSuperLiked,
      );

  /// Effective display name — hides identity for anonymous stories.
  String get displayName => isAnonymous ? 'Anonymous' : (username ?? 'User');

  /// Effective avatar — null for anonymous (caller shows mystery icon).
  String? get displayAvatar => isAnonymous ? null : avatarUrl;
}

// ─── Leaderboard Entry ───────────────────────────────────────
class AfterDarkLeaderEntry {
  final String storyId;
  final String userId;
  final bool isAnonymous;
  final String content;
  final int totalDiamonds;
  final int likeCount;
  final int superLikeCount;
  final String? username;
  final String? avatarUrl;
  final String? topic;
  final DateTime revealDate;

  const AfterDarkLeaderEntry({
    required this.storyId,
    required this.userId,
    required this.isAnonymous,
    required this.content,
    required this.totalDiamonds,
    required this.likeCount,
    required this.superLikeCount,
    required this.revealDate,
    this.username,
    this.avatarUrl,
    this.topic,
  });

  factory AfterDarkLeaderEntry.fromMap(Map<String, dynamic> m) =>
      AfterDarkLeaderEntry(
        storyId:        m['story_id'] as String,
        userId:         m['user_id'] as String,
        isAnonymous:    m['is_anonymous'] as bool? ?? false,
        content:        m['content'] as String,
        totalDiamonds:  m['total_diamonds'] as int? ?? 0,
        likeCount:      m['like_count'] as int? ?? 0,
        superLikeCount: m['super_like_count'] as int? ?? 0,
        username:       m['username'] as String?,
        avatarUrl:      m['avatar_url'] as String?,
        topic:          m['topic'] as String?,
        revealDate:     DateTime.parse(m['reveal_date'] as String),
      );

  String get displayName => isAnonymous ? 'Anonymous' : (username ?? 'User');
  String? get displayAvatar => isAnonymous ? null : avatarUrl;
}
