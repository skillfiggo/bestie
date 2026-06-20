# Online Status Implementation Summary

## ✅ Completed

### Three Online Status States

The app now supports three distinct online statuses:

1. **🟢 Online** - Green circle (#00C853)
   - User is currently active and online
   - Determined by `isOnline = true`

2. **🟡 Away** - Deep Yellow circle (#FFB300)
   - User was recently active but currently idle
   - Shows when user was active within last 5 minutes
   - Determined by `isOnline = false` AND `lastActiveAt` within 5 minutes

3. **⚪ Offline** - Grey circle (#9E9E9E)
   - User is offline or inactive for extended period
   - Shows when user inactive for more than 5 minutes
   - Determined by `isOnline = false` AND `lastActiveAt` older than 5 minutes
     (or null)

### Key Features

- **3-State Status**: Online, Away, Offline.
- **Smooth Transitions**: Animated color changes.
- **Human-Readable Last Seen**: e.g., "Active 2h ago".
- **Privacy Controls**: respects `showOnlineStatus` and `showLastSeen`
  preferences.

### Core Files

- `lib/core/enums/online_status.dart`: Logic and formatting.
- `lib/core/widgets/online_status_indicator.dart`: Widgets.
- `lib/core/widgets/cached_avatar.dart`: Avatar integration.
- `lib/core/widgets/ONLINE_STATUS_README.md`: Docs.
  - Demo screen showing all three status states
  - Usage examples with avatars

4. **`lib/core/widgets/ONLINE_STATUS_README.md`**
   - Comprehensive documentation
   - Usage examples
   - Customization guide

## 🔄 Files Modified

1. **`lib/core/widgets/cached_avatar.dart`**
   - Added optional `onlineStatus` parameter
   - Added optional `statusIndicatorSize` parameter
   - Added optional `showStatusBorder` parameter
   - Automatically wraps avatar with status badge when status provided

2. **`lib/features/social/presentation/screens/followers_following_screen.dart`**
   - Replaced manual online indicator with new status system
   - Now shows all three status states (Online/Away/Offline)

3. **`lib/features/home/presentation/widgets/profile_card.dart`**
   - Updated to use new status system
   - Now shows all three status states on discovery cards

## 🎨 Usage Examples

### Simple Avatar with Status

```dart
CachedAvatar(
  imageUrl: profile.avatarUrl,
  size: 60,
  onlineStatus: getOnlineStatus(
    isOnline: profile.isOnline,
    lastActiveAt: profile.lastActiveAt,
  ),
)
```

### Standalone Status Indicator

```dart
OnlineStatusIndicator(
  status: OnlineStatus.online,
  size: 16,
  showBorder: true,
)
```

## 🔧 Configuration

### Adjust Away Threshold

Edit `lib/core/enums/online_status.dart`:

```dart
// Default: 5 minutes
if (difference.inMinutes < 5) {
  return OnlineStatus.away;
}
```

### Change Colors

Edit `OnlineStatusExtension.color`:

```dart
case OnlineStatus.online:
  return const Color(0xFF00C853); // Green
case OnlineStatus.away:
  return const Color(0xFFFFB300); // Deep Yellow
case OnlineStatus.offline:
  return const Color(0xFF9E9E9E); // Grey
```

## 📍 Where It's Used

- ✅ Profile cards (Home/Discovery screen)
- ✅ Followers/Following lists
- ✅ Can be added to: Chat lists, User profiles, Search results, etc.

## 🎯 Benefits

1. **Reusable** - Works with any avatar or widget
2. **Consistent** - Same colors and behavior throughout app
3. **Flexible** - Customizable size, colors, and thresholds
4. **Smart** - Automatically determines status from profile data
5. **Privacy-aware** - Respects `showOnlineStatus` setting

## 🚀 Next Steps (Optional)

- Add real-time status updates using Supabase Realtime
- Show "Last seen" text for offline users
- Add more statuses (e.g., "In a call", "Do Not Disturb")
- Activity indicators (e.g., "Typing...")
