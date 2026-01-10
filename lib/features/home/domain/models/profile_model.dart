class ProfileModel {
  final String id;
  final String bestieId;
  final String name;
  final String avatarUrl;
  final int age;
  final String gender;
  final String bio;
  final String locationName;
  final String occupation;
  final List<String> interests;
  final String coverPhotoUrl;
  final String verificationPhotoUrl;
  final bool isVerified;
  final bool isOnline;
  final int coins;
  final int diamonds;
  final int freeMessagesCount;
  final DateTime? lastCheckIn;
  final String lookingFor;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final List<String> galleryUrls;
  final String role;
  final String status; // 'active', 'suspended', 'banned'
  final bool showOnlineStatus;
  final bool showLastSeen;
  final DateTime? lastActiveAt;

  const ProfileModel({
    required this.id,
    this.bestieId = '',
    required this.name,
    required this.avatarUrl,
    required this.age,
    required this.gender,
    this.bio = '',
    this.locationName = '',
    this.occupation = '',
    this.interests = const [],
    this.coverPhotoUrl = '',
    this.verificationPhotoUrl = '',
    this.isVerified = false,
    this.isOnline = false,
    this.coins = 0,
    this.diamonds = 0,
    this.freeMessagesCount = 0,
    this.lastCheckIn,
    this.lookingFor = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.galleryUrls = const [],
    this.role = 'user',
    this.status = 'active',
    this.showOnlineStatus = true,
    this.showLastSeen = true,
    this.lastActiveAt,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] ?? '',
      bestieId: map['bestie_id'] ?? '',
      name: map['name'] ?? 'Unknown',
      avatarUrl: map['avatar_url'] ?? '',
      age: map['age'] ?? 18,
      gender: map['gender'] ?? 'other',
      bio: map['bio'] ?? '',
      locationName: map['location'] ?? '',
      occupation: map['occupation'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
      coverPhotoUrl: map['cover_photo_url'] ?? '',
      verificationPhotoUrl: map['verification_photo_url'] ?? '',
      isVerified: map['is_verified'] ?? false,
      isOnline: map['is_online'] ?? false,
      coins: map['coins'] ?? 0,
      diamonds: map['diamonds'] ?? 0,
      freeMessagesCount: map['free_messages_count'] ?? 0,
      lastCheckIn: map['last_check_in'] != null ? DateTime.parse(map['last_check_in']) : null,
      lookingFor: map['looking_for'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      distanceKm: map['distance_km'] != null ? (map['distance_km'] as num).toDouble() : null,
      galleryUrls: List<String>.from(map['gallery_urls'] ?? []),
      role: map['role'] ?? 'user',
      status: map['status'] ?? 'active',
      showOnlineStatus: map['show_online_status'] ?? true,
      showLastSeen: map['show_last_seen'] ?? true,
      lastActiveAt: map['last_active_at'] != null ? DateTime.parse(map['last_active_at']) : null,
    );
  }
}
