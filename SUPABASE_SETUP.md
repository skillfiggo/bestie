# Supabase Setup Guide for Bestie App

## Quick Start

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in with GitHub (or create account)
4. Click "New Project"
5. Fill in:
   - **Name**: bestie-app (or your choice)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to your users
6. Click "Create new project"
7. Wait 2-3 minutes for setup to complete

### 2. Get Your Credentials

1. In your Supabase project dashboard, click **Settings** (gear icon)
2. Click **API** in the sidebar
3. Copy these two values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon public** key (under "Project API keys")

### 3. Update Your .env File

1. Open `.env` file in the root of your project
2. Replace the placeholder values:

```env
SUPABASE_URL=https://your-actual-project-id.supabase.co
SUPABASE_ANON_KEY=your-actual-anon-key-here
```

### 4. Create Database Schema

1. In Supabase dashboard, click **SQL Editor** in the sidebar
2. Click **New query**
3. Open the `supabase_schema.sql` file from your project
4. Copy ALL the SQL code
5. Paste it into the Supabase SQL Editor
6. Click **Run** (or press Ctrl/Cmd + Enter)
7. Wait for "Success. No rows returned" message

### 5. Enable Realtime (Optional but Recommended)

1. In Supabase dashboard, go to **Database** → **Replication**
2. Find the `messages` table
3. Toggle it ON
4. Find the `chats` table
5. Toggle it ON
6. Find the `profiles` table
7. Toggle it ON

### 6. Create Storage Buckets (Optional)

For profile pictures and media:

1. Go to **Storage** in Supabase dashboard
2. Click **New bucket**
3. Create these buckets:
   - **Name**: `avatars`, **Public**: ✅ Yes
   - **Name**: `covers`, **Public**: ✅ Yes
   - **Name**: `chat-media`, **Public**: ✅ Yes

### 7. Run Your App

```bash
# Stop the current running app (if any)
# Press 'q' in the terminal or Ctrl+C

# Restart the app
flutter run
```

## Verification

### Check Console Output

You should see:
```
✅ Supabase initialized successfully
```

If you see an error, check:
- `.env` file has correct credentials
- No typos in URL or key
- `.env` file is in the project root

### Test Authentication

1. Run the app
2. Go to signup screen
3. Create a test account
4. Check Supabase dashboard → **Authentication** → **Users**
5. Your new user should appear!

### Test Database

1. After signup, check **Table Editor** → **profiles**
2. You should see your profile entry

## Troubleshooting

### "Supabase credentials not found"
- Make sure `.env` file exists in project root
- Check that `pubspec.yaml` has `.env` in assets
- Run `flutter pub get`

### "Please update .env file with actual credentials"
- You still have placeholder values in `.env`
- Replace with real Supabase URL and key

### "Failed to initialize Supabase"
- Check internet connection
- Verify Supabase project is active
- Check URL format (should start with `https://`)
- Verify anon key is correct (very long string)

### Tables not created
- Make sure you ran the entire `supabase_schema.sql` file
- Check SQL Editor for error messages
- Try running sections separately if needed

## Next Steps

Once Supabase is set up:

1. ✅ Authentication is ready
2. ✅ Database tables are created
3. ✅ Real-time is enabled
4. 🔄 Start using the app with real backend!

## Security Notes

- ✅ `.env` file is in `.gitignore` (credentials won't be committed)
- ✅ Row Level Security (RLS) is enabled on all tables
- ✅ Users can only access their own data
- ✅ Public profiles are viewable for discovery

## Support

If you encounter issues:
1. Check Supabase dashboard logs
2. Check Flutter console for error messages
3. Verify all setup steps were completed
4. Check Supabase documentation: [supabase.com/docs](https://supabase.com/docs)
