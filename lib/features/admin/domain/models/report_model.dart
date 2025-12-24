class ReportModel {
  final String id;
  final String reporterId;
  final String? reportedUserId;
  final String? reportedMessageId;
  final String reportType; // 'user', 'message', 'profile'
  final String reason;
  final String? description;
  final String status; // 'pending', 'reviewing', 'resolved', 'dismissed'
  final String? adminNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields for display
  final String? reporterName;
  final String? reporterAvatarUrl;
  final String? reportedUserName;
  final String? reportedUserAvatarUrl;

  const ReportModel({
    required this.id,
    required this.reporterId,
    this.reportedUserId,
    this.reportedMessageId,
    required this.reportType,
    required this.reason,
    this.description,
    required this.status,
    this.adminNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
    this.reporterAvatarUrl,
    this.reportedUserName,
    this.reportedUserAvatarUrl,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      reporterId: map['reporter_id'] ?? '',
      reportedUserId: map['reported_user_id'],
      reportedMessageId: map['reported_message_id'],
      reportType: map['report_type'] ?? 'user',
      reason: map['reason'] ?? '',
      description: map['description'],
      status: map['status'] ?? 'pending',
      adminNotes: map['admin_notes'],
      reviewedBy: map['reviewed_by'],
      reviewedAt: map['reviewed_at'] != null 
          ? DateTime.parse(map['reviewed_at']) 
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      reporterName: map['reporter_name'],
      reporterAvatarUrl: map['reporter_avatar_url'],
      reportedUserName: map['reported_user_name'],
      reportedUserAvatarUrl: map['reported_user_avatar_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reported_message_id': reportedMessageId,
      'report_type': reportType,
      'reason': reason,
      'description': description,
      'status': status,
      'admin_notes': adminNotes,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get reasonDisplay {
    switch (reason) {
      case 'spam':
        return 'Spam';
      case 'harassment':
        return 'Harassment';
      case 'inappropriate_content':
        return 'Inappropriate Content';
      case 'fake_profile':
        return 'Fake Profile';
      case 'underage':
        return 'Underage User';
      case 'violence':
        return 'Violence';
      case 'hate_speech':
        return 'Hate Speech';
      case 'sexual_content':
        return 'Sexual Content';
      case 'scam':
        return 'Scam/Fraud';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'reviewing':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'dismissed':
        return 'Dismissed';
      default:
        return status;
    }
  }
}
