/// Provides gender-specific placeholder avatar images for users who have not
/// yet set a profile picture.
///
/// Each user is deterministically assigned one of 3 male or female avatars
/// based on their user ID, so the same user always sees the same placeholder.
class DefaultAvatarHelper {
  DefaultAvatarHelper._();

  static const _maleAvatars = [
    'assets/images/avatars/male_avatar_1.png',
    'assets/images/avatars/male_avatar_2.png',
    'assets/images/avatars/male_avatar_3.png',
    'assets/images/avatars/male_avatar_4.png',
    'assets/images/avatars/male_avatar_5.png',
    'assets/images/avatars/male_avatar_6.png',
    'assets/images/avatars/male_avatar_7.png',
    'assets/images/avatars/male_avatar_8.png',
    'assets/images/avatars/male_avatar_9.png',
  ];

  static const _femaleAvatars = [
    'assets/images/avatars/female_avatar_1.png',
    'assets/images/avatars/female_avatar_2.png',
    'assets/images/avatars/female_avatar_3.png',
  ];

  /// Returns an asset path for a placeholder avatar.
  ///
  /// [userId] is used to pick consistently (same user → same image).
  /// [gender] should be `'male'` or `'female'`; anything else defaults to female.
  static String getAssetPath(String userId, String? gender) {
    final isMale = gender?.toLowerCase() == 'male';
    final pool = isMale ? _maleAvatars : _femaleAvatars;
    final index = userId.hashCode.abs() % pool.length;
    return pool[index];
  }

  /// Returns true if [avatarUrl] is empty / null and a placeholder should be used.
  static bool needsPlaceholder(String? avatarUrl) =>
      avatarUrl == null || avatarUrl.trim().isEmpty;

  /// Normalizes avatar path. If it is a local asset, ensures the file exists or falls back to a valid one.
  static String normalizeAvatarUrl(String? url, String userId, String? gender) {
    if (needsPlaceholder(url)) {
      return getAssetPath(userId, gender);
    }
    if (url!.startsWith('assets/')) {
      final isMale = url.contains('male_avatar_');
      final numStr = RegExp(r'\d+').stringMatch(url.split('/').last);
      final num = int.tryParse(numStr ?? '') ?? 1;
      if (isMale) {
        if (num >= 1 && num <= 9) return url;
        return 'assets/images/avatars/male_avatar_${(num % 9) + 1}.png';
      } else {
        if (num >= 1 && num <= 3) return url;
        return 'assets/images/avatars/female_avatar_${(num % 3) + 1}.png';
      }
    }
    return url;
  }
}
