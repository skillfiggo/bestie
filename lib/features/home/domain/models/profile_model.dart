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
  final String lookingFor;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final List<String> galleryUrls;
  final String role;
  final String status; // 'active', 'suspended', 'banned'

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
    this.lookingFor = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.galleryUrls = const [],
    this.role = 'user',
    this.status = 'active',
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
      lookingFor: map['looking_for'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      distanceKm: map['distance_km'] != null ? (map['distance_km'] as num).toDouble() : null,
      galleryUrls: List<String>.from(map['gallery_urls'] ?? []),
      role: map['role'] ?? 'user',
      status: map['status'] ?? 'active',
    );
  }
}
