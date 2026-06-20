# Follow Functionality Troubleshooting Guide

## Problem

Following other users isn't working in the release APK.

## Root Cause

The issue is most likely related to Row Level Security (RLS) policies on the
`follows` table not being properly configured in the Supabase database.

## Solution

### Step 1: Run the SQL Fix Script

Execute `fix_follow_functionality.sql` in your Supabase SQL Editor:

1. Go to Supabase Dashboard → SQL Editor
2. Click "New Query"
3. Copy and paste the contents of `fix_follow_functionality.sql`
4. Click "Run" or press Ctrl+Enter

This script will:

- Remove any conflicting RLS policies
- Create proper policies for SELECT, INSERT, and DELETE operations
- Ensure all necessary constraints and indexes exist
- Grant appropriate permissions to authenticated users

### Step 2: Verify the Fix

After running the SQL script, test the following:

#### Test 1: Check if policies exist

```sql
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'follows';
```

You should see three policies:

- `Anyone can view follows` (SELECT)
- `Users can create their own follows` (INSERT)
- `Users can delete their own follows` (DELETE)

#### Test 2: Check table structure

```sql
SELECT 
  constraint_name, 
  constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'follows';
```

You should see:

- Primary key constraint
- Unique constraint on (follower_id, following_id)
- Check constraint preventing self-follows
- Foreign key constraints to profiles table

#### Test 3: Manual follow test

Replace `USER_ID_HERE` with an actual user UUID:

```sql
-- Get current user's ID
SELECT auth.uid();

-- Try to insert a follow (as if you're following someone)
INSERT INTO follows (follower_id, following_id)
VALUES (auth.uid(), 'USER_ID_HERE');

-- Check if it was inserted
SELECT * FROM follows WHERE follower_id = auth.uid();

-- Clean up test data
DELETE FROM follows WHERE follower_id = auth.uid() AND following_id = 'USER_ID_HERE';
```

### Step 3: Rebuild and Test the App

1. **Clean build**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build release APK**:
   ```bash
   flutter build apk --release
   ```

3. **Install and test**:
   - Install the new APK on your device
   - Try to follow/unfollow users
   - Check the console logs for detailed error messages

## Debugging

### Check Console Logs

The updated `follow_repository.dart` now includes detailed error logging. When a
follow action fails, you'll see:

```
Follow error details: [specific error message]
```

### Common Error Messages

| Error Message                                    | Cause                           | Solution                  |
| ------------------------------------------------ | ------------------------------- | ------------------------- |
| "You are already following this user"            | Duplicate follow attempt        | This is normal behavior   |
| "Unable to follow user. Please try again later." | RLS policy blocking the action  | Run the SQL fix script    |
| "User not found"                                 | Invalid user ID or user deleted | Check if the user exists  |
| "Network error..."                               | Connection issues               | Check internet connection |

### Manual Database Check

Check if RLS is causing issues:

```sql
-- Temporarily disable RLS (FOR TESTING ONLY - DON'T USE IN PRODUCTION)
ALTER TABLE follows DISABLE ROW LEVEL SECURITY;

-- Try to follow someone in the app
-- If it works, the issue is with RLS policies

-- Re-enable RLS
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
```

### Check User Authentication

Ensure users are properly authenticated:

```sql
-- Check if the current user is authenticated
SELECT auth.uid();

-- If this returns NULL, the user is not authenticated
-- They need to sign in first
```

## Prevention

To prevent this issue in the future:

1. **Always test follow functionality** after deploying database changes
2. **Keep RLS policies in sync** across development and production
3. **Monitor error logs** in the app for policy-related issues
4. **Use the SQL fix script** as a template for future policy updates

## Additional Notes

- The `follows` table has a unique constraint on (follower_id, following_id),
  preventing duplicate follows
- A check constraint prevents users from following themselves
- The updated code now provides user-friendly error messages instead of
  technical details
- All follow/unfollow actions are logged for easier debugging

## Still Having Issues?

If the problem persists after following these steps:

1. Check the Supabase logs:
   - Dashboard → Logs → API Logs
   - Look for 403 (Forbidden) errors related to the `follows` table

2. Verify authentication:
   - Ensure the user is logged in
   - Check that `auth.uid()` returns a valid UUID

3. Check database connectivity:
   - Ensure the app can connect to Supabase
   - Test with other database operations

4. Review the foreign key constraints:
   - Ensure both follower_id and following_id reference valid profiles
