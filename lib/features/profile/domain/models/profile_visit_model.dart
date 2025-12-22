import 'package:bestie/features/home/domain/models/profile_model.dart';

class ProfileVisit {
  final String id;
  final String visitorId;
  final String visitedId;
  final DateTime visitedAt;
  final ProfileModel? visitorProfile; // Loaded when showing "Visited Me"
  final ProfileModel? visitedProfile; // Loaded when showing "I Visited"

  const ProfileVisit({
    required this.id,
    required this.visitorId,
    required this.visitedId,
    required this.visitedAt,
    this.visitorProfile,
    this.visitedProfile,
  });

  factory ProfileVisit.fromMap(Map<String, dynamic> map) {
    return ProfileVisit(
      id: map['id'] ?? '',
      visitorId: map['visitor_id'] ?? '',
      visitedId: map['visited_id'] ?? '',
      visitedAt: map['visited_at'] != null 
          ? DateTime.parse(map['visited_at']).toLocal() 
          : DateTime.now(),
      visitorProfile: map['visitor_profile'] != null 
          ? ProfileModel.fromMap(map['visitor_profile']) 
          : null,
      visitedProfile: map['visited_profile'] != null 
          ? ProfileModel.fromMap(map['visited_profile']) 
          : null,
    );
  }
}
