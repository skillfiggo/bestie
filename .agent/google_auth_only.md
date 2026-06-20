# Google Sign-in: Authentication Only (No Auto-fill)

## Summary

Modified the Google sign-in implementation to use Gmail **for authentication
purposes only**, without automatically filling in user details (name, profile
photo, username, age, etc.) from their Google account.

## Changes Made

### 1. Modified `auth_repository.dart`

**File**: `lib/features/auth/data/repositories/auth_repository.dart`

**What Changed**:

- Removed auto-population of user details from Google account during sign-in
- Previously, the app would automatically set:
  - `name` from `googleUser.displayName`
  - `avatar_url` from `googleUser.photoUrl`
- Now, only the `email` is stored for authentication

**Key Points**:

- **New Google Users**: Profile is created with minimal data (email only) and
  `status: 'pending_profile'`
- **Existing Users**: Their existing profile data is preserved; only email is
  updated if changed
- **No Auto-fill**: Name, avatar, age, gender, bio, and all other fields remain
  empty until user manually completes them

### 2. Existing Flow Already Handles This

**File**: `lib/features/auth/presentation/screens/auth_landing_screen.dart`

The existing navigation logic (lines 120-136) already checks for incomplete
profiles and redirects users to complete their profile setup. This works
perfectly with our changes because:

1. New Google sign-in users will have:
   - `status: 'pending_profile'`
   - `name: 'New User'` (default)
   - Empty/null gender

2. The app detects this and navigates to `AppRouter.authForms` (signup flow)

3. Users must manually enter:
   - Their name
   - Age/Date of birth
   - Gender
   - Bio
   - Profile photo
   - Other profile details

## User Experience

### Before (Auto-fill):

1. User clicks "Google" button
2. Authenticates with Google
3. App automatically uses Google name and photo
4. User goes directly to main app ⚡

### After (Authentication Only):

1. User clicks "Google" button
2. Authenticates with Google (email verified)
3. App detects incomplete profile
4. User is redirected to profile setup forms
5. User manually enters all details
6. User completes profile and enters main app ✅

## Benefits

- ✅ **Privacy**: Users control what information they share
- ✅ **Consistency**: All users (email and Google) go through the same profile
  setup
- ✅ **Flexibility**: Users can choose different names/photos than their Google
  account
- ✅ **Security**: Only email is used from Google (for
  authentication/verification)

## Testing Checklist

- [ ] New Google user signs in → Redirected to profile setup
- [ ] User completes profile manually → All fields saved correctly
- [ ] Existing Google user signs in → Existing profile preserved
- [ ] No Google data (name/photo) auto-filled
- [ ] Email-based signup still works normally
