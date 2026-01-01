class AgoraTokenResponse {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final int expiresAt;

  AgoraTokenResponse({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.expiresAt,
  });

  factory AgoraTokenResponse.fromJson(Map<String, dynamic> json) {
    return AgoraTokenResponse(
      token: json['token'] as String,
      appId: json['appId'] as String,
      channelName: json['channelName'] as String,
      uid: json['uid'] as int,
      expiresAt: json['expiresAt'] as int,
    );
  }
}
