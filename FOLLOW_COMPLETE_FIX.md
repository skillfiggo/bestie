# Follow Functionality - Complete Fix Guide

## Error: "column 'following_count' does not exist"

### Problem

When viewing a user's profile, you see this error:

```
PostgrestException(message: column "following_count" does not exist, code: 42703)
```

### Root Cause

The `profiles` table is missing the `follower_count` and `following_count`
columns that the app expects to find.

### Complete Solution (2 SQL Scripts Required)

#### Step 1: Add Missing Columns

Run `add_follow_count_columns.sql` in Supabase SQL Editor:

1. Go to Supabase Dashboard → SQL Editor
2. Click "New Query"
3. Copy and paste the contents of `add_follow_count_columns.sql`
4. Click "Run"

This script will:

- ✅ Add `follower_count` and `following_count` columns to `profiles` table
- ✅ Create triggers to automatically update counts
- ✅ Initialize counts for all existing users
- ✅ Create indexes for better performance

#### Step 2: Fix Follow Permissions

Run `fix_follow_functionality.sql` in Supabase SQL Editor:

1. In the same SQL Editor
2. Create another new query
3. Copy and paste the contents of `fix_follow_functionality.sql`
4. Click "Run"

This script will:

- ✅ Remove conflicting RLS policies
- ✅ Create proper policies for authenticated users
- ✅ Grant necessary permissions
- ✅ Ensure all constraints are in place

### Verification

After running both scripts, verify the fix:

```sql
-- Check if columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND column_name IN ('follower_count', 'following_count');

-- Should return:
-- follower_count | integer
-- following_count | integer

-- Check if triggers exist
SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'follows';

-- Should return:
-- update_follow_counts_on_insert
-- update_follow_counts_on_delete

-- Test the counts (replace USER_ID with an actual UUID)
SELECT 
  name,
  follower_count,
  following_count
FROM profiles
WHERE id = 'YOUR_USER_ID';
```

### Rebuild and Test

1. Clean and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. Install the new APK on your device

3. Test:
   - View different user profiles
   - Try to follow/unfollow users
   - Check that follower/following counts update correctly

## Additional Troubleshooting

### If counts are not updating:

```sql
-- Manually trigger count update for all users
UPDATE profiles p
SET 
  follower_count = (SELECT COUNT(*) FROM follows WHERE following_id = p.id),
  following_count = (SELECT COUNT(*) FROM follows WHERE follower_id = p.id);
```

### If you still see "permission denied" errors:

```sql
-- Check current RLS policies
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'follows';

-- Temporarily disable RLS for testing (DO NOT USE IN PRODUCTION!)
ALTER TABLE follows DISABLE ROW LEVEL SECURITY;
-- Test if follows work now
-- Then re-enable:
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
```

### Check function and trigger status:

```sql
-- Check if the update function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'update_follow_counts';

-- Check trigger configuration
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'follows';
```

## How It Works

### Before (Error):

```
User tries to view profile
  ↓
App queries: SELECT * FROM profiles WHERE id = 'xxx'
  ↓
Database tries to return follower_count, following_count
  ↓
ERROR: Columns don't exist!
```

### After (Fixed):

```
User tries to view profile
  ↓
App queries: SELECT * FROM profiles WHERE id = 'xxx'
  ↓
Database returns all columns including follower_count, following_count
  ↓
SUCCESS: Profile displayed with accurate counts!

User follows someone
  ↓
INSERT INTO follows (follower_id, following_id) ...
  ↓
Trigger automatically updates both users' counts
  ↓
SUCCESS: Counts always stay accurate!
```

## Prevention

To prevent this in the future:

1. **Always run database migrations** when updating the app
2. **Test with fresh database** state to catch missing columns
3. **Keep schema documentation** up to date
4. **Use migration scripts** instead of manual database changes

## Quick Checklist

- [ ] Run `add_follow_count_columns.sql`
- [ ] Run `fix_follow_functionality.sql`
- [ ] Verify columns exist in database
- [ ] Verify triggers are working
- [ ] Rebuild Flutter app (`flutter clean && flutter build apk --release`)
- [ ] Install new APK
- [ ] Test follow/unfollow functionality
- [ ] Verify counts update correctly
- [ ] Check that no errors appear when viewing profiles

## Still Having Issues?

1. Check Supabase logs for specific error messages
2. Ensure you're testing with users that have valid UUIDs
3. Verify that the `follows` table exists
4. Check that foreign keys are properly set up
5. Review the enhanced error messages in the console logs
