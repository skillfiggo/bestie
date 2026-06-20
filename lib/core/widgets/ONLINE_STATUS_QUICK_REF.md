# 🟢 🟡 ⚪ Online Status - Quick Reference

## Three Status States

| Status         | Color       | Hex       | When Shown              |
| -------------- | ----------- | --------- | ----------------------- |
| 🟢 **Online**  | Green       | `#00C853` | `isOnline = true`       |
| 🟡 **Away**    | Deep Yellow | `#FFB300` | Active within 5 minutes |
| ⚪ **Offline** | Grey        | `#9E9E9E` | Inactive > 5 minutes    |

## Quick Start

```dart
// 1. Import
import 'package:bestie/core/enums/online_status.dart';
import 'package:bestie/core/widgets/cached_avatar.dart';

// 2. Get status
final status = getOnlineStatus(
  isOnline: profile.isOnline,
  lastActiveAt: profile.lastActiveAt,
);

// 3. Use it
CachedAvatar(
  imageUrl: profile.avatarUrl,
  size: 60,
  onlineStatus: status,
)
```

## Files to Know

- **Define**: `lib/core/enums/online_status.dart`
- **Widgets**: `lib/core/widgets/online_status_indicator.dart`
- **Enhanced**: `lib/core/widgets/cached_avatar.dart`
- **Docs**: `lib/core/widgets/ONLINE_STATUS_README.md`

## Common Tasks

### Change Away Timeout

`lib/core/enums/online_status.dart` line ~50:

```dart
if (difference.inMinutes < 10) { // Change from 5 to 10
```

### Change Colors

`lib/core/enums/online_status.dart` line ~20:

```dart
case OnlineStatus.online:
  return const Color(0xFF00C853); // Your color
```

### Custom Size

```dart
CachedAvatar(
  onlineStatus: status,
  statusIndicatorSize: 18, // Custom size
)
```

### Hide Border

```dart
CachedAvatar(
  onlineStatus: status,
  showStatusBorder: false,
)
```

## Integration Checklist

✅ Profile discovery cards\
✅ Followers/Following lists\
✅ Friends & Besties tabs\
⬜ Chat list (ready to add)\
⬜ User profile header (ready to add)\
⬜ Search results (ready to add)

---

**Tip**: See full examples in `online_status_example.dart`
