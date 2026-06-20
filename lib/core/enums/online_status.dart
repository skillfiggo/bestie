import 'package:flutter/material.dart';

/// Represents the online status of a user
enum OnlineStatus {
  /// User is currently active and online
  online,
  
  /// User was recently active but is currently away (idle)
  away,
  
  /// User is offline
  offline,
}

extension OnlineStatusExtension on OnlineStatus {
  /// Returns the color associated with each status
  Color get color {
    switch (this) {
      case OnlineStatus.online:
        return const Color(0xFF00C853); // Green
      case OnlineStatus.away:
        return const Color(0xFFFFB300); // Deep Yellow/Amber
      case OnlineStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  /// Returns a readable label for the status
  String get label {
    switch (this) {
      case OnlineStatus.online:
        return 'Online';
      case OnlineStatus.away:
        return 'Away';
      case OnlineStatus.offline:
        return 'Offline';
    }
  }
}

/// Helper function to determine online status based on various factors
OnlineStatus getOnlineStatus({
  required bool isOnline,
  DateTime? lastActiveAt,
}) {
  if (isOnline) {
    return OnlineStatus.online;
  }
  
  // If user is not online, check when they were last active
  if (lastActiveAt != null) {
    final difference = DateTime.now().difference(lastActiveAt);
    
    // If active within the last 5 minutes, show as away
    // Otherwise, show as offline
    if (difference.inMinutes < 5) {
      return OnlineStatus.away;
    }
  }
  
  return OnlineStatus.offline;
}

/// Formats the last active time into a human-readable "last seen" text
/// Returns text like "Active now", "Active 2m ago", "Active 2h ago", etc.
String getLastSeenText({
  required bool isOnline,
  DateTime? lastActiveAt,
}) {
  // If currently online
  if (isOnline) {
    return 'Active now';
  }
  
  // If no last active time is available
  if (lastActiveAt == null) {
    return 'Offline';
  }
  
  final difference = DateTime.now().difference(lastActiveAt);
  
  // Less than 1 minute
  if (difference.inSeconds < 60) {
    return 'Active just now';
  }
  
  // Less than 1 hour (show minutes)
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return 'Active ${minutes}m ago';
  }
  
  // Less than 24 hours (show hours)
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return 'Active ${hours}h ago';
  }
  
  // Less than 7 days (show days)
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return 'Active ${days}d ago';
  }
  
  // Less than 30 days (show weeks)
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return 'Active ${weeks}w ago';
  }
  
  // More than 30 days
  final months = (difference.inDays / 30).floor();
  if (months == 1) {
    return 'Active 1 month ago';
  } else if (months < 12) {
    return 'Active $months months ago';
  }
  
  // More than a year
  return 'Active long ago';
}
