# Online Status Indicators

This document explains the three-state online status indicator system
implemented in the Bestie app.

## Overview

The app now supports three distinct online statuses for users:

| Status      | Color                   | Description                                                            |
| ----------- | ----------------------- | ---------------------------------------------------------------------- |
| **Online**  | Green (`#00C853`)       | User is currently active and online                                    |
| **Away**    | Deep Yellow (`#FFB300`) | User was recently active but is currently idle (within last 5 minutes) |
| **Offline** | Grey (`#9E9E9E`)        | User is offline or inactive for more than 5 minutes                    |

## Files

### Core Files

- **`lib/core/enums/online_status.dart`** - Defines the `OnlineStatus` enum and
  helper functions
- **`lib/core/widgets/online_status_indicator.dart`** - Reusable status
  indicator widgets
- **`lib/core/widgets/online_status_example.dart`** - Example usage and demos

### Updated Files

- **`lib/core/widgets/cached_avatar.dart`** - Enhanced to support optional
  status badges
- **`lib/features/social/presentation/screens/followers_following_screen.dart`** -
  Uses status in user lists
- **`lib/features/home/presentation/widgets/profile_card.dart`** - Shows status
  on profile cards

## Usage

### Basic Usage

```dart
import 'package:bestie/core/enums/online_status.dart';
import 'package:bestie/core/widgets/online_status_indicator.dart';

// Show a standalone status indicator
OnlineStatusIndicator(
  status: OnlineStatus.online,
  size: 16,
  showBorder: true,
)
```

### With CachedAvatar

The `CachedAvatar` widget now accepts optional status parameters:

```dart
import 'package:bestie/core/widgets/cached_avatar.dart';
import 'package:bestie/core/enums/online_status.dart';

CachedAvatar(
  imageUrl: profile.avatarUrl,
  size: 60,
  fallbackText: profile.name,
  onlineStatus: status,  // Optional: Add status badge
  statusIndicatorSize: 14,  // Optional: Custom indicator size
  showStatusBorder: true,  // Optional: Show white border
)
```

### With ProfileModel

Use the helper function to determine status from profile data:

```dart
import 'package:bestie/core/enums/online_status.dart';

final status = getOnlineStatus(
  isOnline: profile.isOnline,
  lastActiveAt: profile.lastActiveAt,
);

// Then use the status with any widget
CachedAvatar(
  imageUrl: profile.avatarUrl,
  onlineStatus: status,
)
```

### StatusBadge Widget

For custom layouts, use `StatusBadge` to position status on any widget:

```dart
import 'package:bestie/core/widgets/online_status_indicator.dart';

StatusBadge(
  status: OnlineStatus.online,
  indicatorSize: 12,
  alignment: Alignment.bottomRight,
  child: YourCustomWidget(),
)
```

## Features

- **Three States**: Online (Green), Away (Deep Yellow), and Offline (Grey).
- **Smooth Animations**: Animated color transitions between states using
  `AnimatedContainer`.
- **Last Seen Text**: Formatted "Active now", "Active 5m ago", etc., via
  `getLastSeenText`.
- **Privacy First**: Respects `showOnlineStatus` and `showLastSeen` user
  preferences.
- **Ready Widgets**: `OnlineStatusIndicator`, `StatusBadge`, and
  `StatusWithText`.

## Status Logic

The `getOnlineStatus()` function determines status based on two factors:

1. **`isOnline`** (boolean) - If `true`, user is **Online**
2. **`lastActiveAt`** (DateTime?) - Used when `isOnline` is `false`:
   - If active within last 5 minutes → **Away**
   - Otherwise → **Offline**

```dart
OnlineStatus getOnlineStatus({
  required bool isOnline,
  DateTime? lastActiveAt,
}) {
  if (isOnline) {
    return OnlineStatus.online;
  }
  
  if (lastActiveAt != null) {
    final difference = DateTime.now().difference(lastActiveAt);
    if (difference.inMinutes < 5) {
      return OnlineStatus.away;
    }
  }
  
  return OnlineStatus.offline;
}
```

### Customizing the Away Threshold

To change when a user transitions from "Away" to "Offline", edit the threshold
in `lib/core/enums/online_status.dart`:

```dart
// Current: 5 minutes
if (difference.inMinutes < 5) {
  return OnlineStatus.away;
}

// Example: Change to 10 minutes
if (difference.inMinutes < 10) {
  return OnlineStatus.away;
}
```

## Customization

### 3. Last Seen Logic

`lib/core/enums/online_status.dart` also provides `getLastSeenText()`:

- 🟢 **Online**: "Active now"
- 🟡 **Away**: "Active Xm ago" (if < 60m)
- ⚪ **Offline**: "Active Xh/d ago" or "Offline"

### 4. Privacy Handling

All components check:

- `profile.showOnlineStatus`: If `false`, the indicator is hidden.
- `profile.showLastSeen`: If `false`, the "Last seen" text is hidden.

### Colors

To change status colors, edit the `OnlineStatusExtension` in
`lib/core/enums/online_status.dart`:

```dart
Color get color {
  switch (this) {
    case OnlineStatus.online:
      return const Color(0xFF00C853); // Change green color
    case OnlineStatus.away:
      return const Color(0xFFFFB300); // Change yellow color
    case OnlineStatus.offline:
      return const Color(0xFF9E9E9E); // Change grey color
  }
}
```

### Size

The default indicator size is 20% of the avatar size (clamped between 8-16px).
To customize:

```dart
CachedAvatar(
  size: 60,
  statusIndicatorSize: 18,  // Override default calculation
  onlineStatus: status,
)
```

### Border

The status indicator has a white border by default for better visibility. To
remove it:

```dart
CachedAvatar(
  onlineStatus: status,
  showStatusBorder: false,  // Remove white border
)
```

## Where It's Used

The online status system is currently integrated in:

1. **Profile Cards** (`profile_card.dart`) - Shows status on discovery cards
2. **Followers/Following Lists** (`followers_following_screen.dart`) - Shows
   status for each user
3. **User Profiles** (ready to use) - Can be added to `user_profile_screen.dart`

## Future Enhancements

Possible improvements:

- Real-time status updates using Supabase Realtime subscriptions
- Last seen text (e.g., "Active 2 hours ago")
- Do Not Disturb status
- Custom status messages
- Activity-based status (e.g., "In a call", "Typing...")

## Example Screen

To see all status states in action, you can navigate to the example screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const OnlineStatusExample(),
  ),
);
```

## Database Schema

The system uses existing fields in the `profiles` table:

- `is_online` (boolean) - Whether user is currently online
- `last_active_at` (timestamp) - Last activity timestamp
- `show_online_status` (boolean) - Privacy setting to hide/show status

No database changes are required to use this feature.
