class BroadcastModel {
  final String id;
  final String title;
  final String message;
  final bool isActive;
  final DateTime createdAt;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkText;

  BroadcastModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isActive,
    required this.createdAt,
    this.imageUrl,
    this.linkUrl,
    this.linkText,
  });

  factory BroadcastModel.fromMap(Map<String, dynamic> map) {
    return BroadcastModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      isActive: map['is_active'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      imageUrl: map['image_url'],
      linkUrl: map['link_url'],
      linkText: map['link_text'],
    );
  }
}
