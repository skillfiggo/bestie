# Follow Feature - Setup Checklist

## ⚠️ IMPORTANT: Database Migration Required

Before the Follow button will appear, you MUST run the database migration!

### Step-by-Step Instructions:

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Copy and Run Migration**
   - Open the file: `supabase_follows_migration.sql`
   - Copy ALL the SQL code
   - Paste it into the SQL Editor
   - Click "Run" or press Ctrl+Enter

4. **Verify Table Created**
   - Go to "Table Editor" in the left sidebar
   - You should see a new table called "follows"
   - It should have columns: id, follower_id, following_id, created_at

5. **Hot Restart the App**
   - In the terminal where Flutter is running
   - Press `R` (capital R) for hot restart
   - Or stop and run `flutter run` again

### Troubleshooting

**If you still don't see the Follow button:**

1. Check browser console for errors (F12)
2. Verify the `follows` table exists in Supabase
3. Make sure you did a hot restart (not just hot reload)
4. Try stopping the app completely and running `flutter run` again

**Common Errors:**

- "relation 'follows' does not exist" → Database migration not run
- "permission denied" → RLS policies not created properly
- Button not showing → App needs hot restart

### What the Follow Button Should Look Like

- **Location**: Below user's name and info, above Chat/Video/Call buttons
- **When not following**: Orange button with "Follow" text and person_add icon
- **When following**: Gray button with "Unfollow" text and person_remove icon
- **During action**: Loading indicator

### Files to Check

- Migration SQL: `supabase_follows_migration.sql`
- User Profile Screen: `lib/features/profile/presentation/screens/user_profile_screen.dart`
- Follow Repository: `lib/features/social/data/repositories/follow_repository.dart`
