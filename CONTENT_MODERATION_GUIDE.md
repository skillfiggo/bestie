# Content Moderation & Reports System

## Overview
A comprehensive content moderation system that allows users to report inappropriate content/users and admins to review and take action on reports.

## Database Setup

### Run this SQL in your Supabase SQL Editor:
Execute the file: `create_reports_schema.sql`

This creates:
- **reports table**: Stores all user reports with status tracking
- **blocked_users table**: Manages user blocking functionality
- **RLS policies**: Ensures users can only see their own reports, admins can see all
- **Indexes**: For optimal query performance
- **Triggers**: Auto-update timestamps

## Features Implemented

### For Users:
1. **Report Users** - Report inappropriate profiles
2. **Report Messages** - Report offensive messages
3. **Block Users** - Block users to prevent interaction
4. **View Own Reports** - Track status of submitted reports

### For Admins:
1. **View All Reports** - See all submitted reports
2. **Filter Reports** - By status (pending, reviewing, resolved, dismissed)
3. **Review Reports** - Mark as reviewing, resolve, or dismiss
4. **Take Action**:
   - Ban reported users
   - Delete reported messages
   - Add admin notes
5. **Track Moderation** - See who reviewed what and when

## Report Reasons
- Spam
- Harassment
- Inappropriate Content
- Fake Profile
- Underage User
- Violence
- Hate Speech
- Sexual Content
- Scam/Fraud
- Other

## Report Statuses
- **Pending**: Newly submitted, awaiting review
- **Reviewing**: Admin is actively reviewing
- **Resolved**: Action taken, issue resolved
- **Dismissed**: No action needed

## How to Use

### For Users - Reporting Content:
```dart
import 'package:bestie/features/admin/presentation/widgets/report_dialog.dart';

// Show report dialog
showReportDialog(
  context,
  reportedUserId: 'user-id-here',
  reportedUserName: 'John Doe',
  reportType: 'user', // or 'message', 'profile'
  reportedMessageId: 'message-id-here', // optional, for message reports
);
```

### For Admins - Accessing Reports:
1. Go to **Settings** → **Admin Dashboard**
2. Tap the **red flag icon** (🚩) in the app bar
3. View and manage all reports

## Admin Actions Available:
- **Mark as Reviewing** - Start reviewing a pending report
- **Resolve Report** - Mark as resolved with optional notes
- **Dismiss Report** - Dismiss if no action needed
- **Ban User** - Ban the reported user from the app
- **Delete Message** - Remove the reported message

## Integration Points

### Add Report Button to User Profiles:
```dart
IconButton(
  icon: const Icon(Icons.flag),
  onPressed: () {
    showReportDialog(
      context,
      reportedUserId: userId,
      reportedUserName: userName,
      reportType: 'user',
    );
  },
)
```

### Add Report Button to Messages:
```dart
// In message long-press menu
showReportDialog(
  context,
  reportedUserId: message.senderId,
  reportedUserName: senderName,
  reportType: 'message',
  reportedMessageId: message.id,
);
```

## Files Created:
1. `create_reports_schema.sql` - Database schema
2. `lib/features/admin/domain/models/report_model.dart` - Report data model
3. `lib/features/admin/data/repositories/reports_repository.dart` - Data layer
4. `lib/features/admin/presentation/screens/admin_reports_screen.dart` - Admin UI
5. `lib/features/admin/presentation/widgets/report_dialog.dart` - User report dialog

## Security Features:
- ✅ RLS policies ensure data privacy
- ✅ Users can only see their own reports
- ✅ Only admins can view all reports
- ✅ Only admins can update report status
- ✅ Automatic timestamp tracking
- ✅ Reviewer tracking (who handled each report)

## Next Steps:
1. Run the SQL schema in Supabase
2. Add report buttons to user profiles
3. Add report buttons to message long-press menus
4. Test the full flow from user report to admin action
