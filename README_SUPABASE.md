# Supabase Integration - Quick Reference

## ✅ What's Been Set Up

### Core Files Created
- `lib/core/services/supabase_service.dart` - Supabase client singleton
- `lib/features/auth/data/repositories/auth_repository.dart` - Authentication repository
- `.env` - Environment variables (YOU NEED TO UPDATE THIS!)
- `.env.example` - Template for environment variables
- `supabase_schema.sql` - Complete database schema
- `SUPABASE_SETUP.md` - Detailed setup instructions

### Packages Installed
- ✅ `supabase_flutter: ^2.0.0`
- ✅ `flutter_dotenv: ^5.1.0`

### Configuration
- ✅ Main.dart updated with Supabase initialization
- ✅ .env added to .gitignore for security
- ✅ .env added to pubspec.yaml assets

## 🚀 Quick Start (3 Steps)

### Step 1: Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Copy **Project URL** and **anon key**

### Step 2: Update .env File
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### Step 3: Run Database Schema
1. Open Supabase SQL Editor
2. Copy all content from `supabase_schema.sql`
3. Paste and run

## 📊 Database Tables

- **profiles** - User profiles with coins, diamonds, interests
- **chats** - Chat conversations between users
- **messages** - Individual messages with real-time support
- **call_history** - Voice and video call records
- **visitors** - Profile visit tracking
- **friendships** - Friend and bestie relationships

## 🔐 Security

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ Users can only access their own data
- ✅ Public profiles viewable for discovery
- ✅ Credentials secured in .env (not committed to git)

## 🎯 Features Ready

### Authentication
```dart
final authRepo = AuthRepository();

// Sign up
await authRepo.signUp(
  email: 'user@example.com',
  password: 'password',
  userData: {'name': 'John', 'age': 25, 'gender': 'male'},
);

// Sign in
await authRepo.signIn(
  email: 'user@example.com',
  password: 'password',
);

// Sign out
await authRepo.signOut();
```

### Accessing Supabase Client
```dart
import 'package:bestie/core/services/supabase_service.dart';

// Get client
final supabase = SupabaseService.client;

// Check auth
if (SupabaseService.isAuthenticated) {
  final userId = SupabaseService.currentUserId;
}
```

## 📝 Next Steps

1. **Update .env** with your Supabase credentials
2. **Run schema** in Supabase SQL Editor
3. **Restart app** to initialize Supabase
4. **Test signup** to verify everything works

## 📚 Full Documentation

See `SUPABASE_SETUP.md` for detailed setup instructions and troubleshooting.

## ⚠️ Important Notes

- The app will show a warning if Supabase credentials are not configured
- Mock data will be replaced with real data once Supabase is set up
- Real-time messaging requires Realtime to be enabled in Supabase dashboard
- Storage buckets needed for profile pictures and media uploads

## 🐛 Troubleshooting

**App shows "Failed to initialize Supabase"**
→ Check `.env` file has correct credentials

**"Supabase credentials not found"**
→ Run `flutter pub get` and restart app

**Tables not found**
→ Run `supabase_schema.sql` in Supabase SQL Editor

---

**Ready to go!** Update your `.env` file and restart the app to start using Supabase! 🎉
