# Gmail Signup Flow - Fixed

## Issue

Users signing up with Gmail were experiencing an auto-skip from the Gender
selection step directly to Photo Verification, **skipping the Nickname and DOB
entry step**.

## Expected Flow (Now Fixed)

1. User picks Gmail account to sign up with
2. User picks gender (Male/Female)
3. User inputs Nickname and DOB ✅ **Was being skipped**
4. User uploads Verification Image (if female)
5. User sees Main Frame

## Root Cause

In `signup_screen.dart`, the `_onGenderSelected()` method was using
`_nextPage()` to navigate after gender selection. This was intended to move from
page 3 (Gender) to page 4 (Profile Details), but something was causing it to
skip directly to page 5 (Photo Verification) for female users.

## Fix Applied

### Modified: `lib/features/auth/presentation/screens/signup_screen.dart`

Changed the navigation in `_onGenderSelected()` from a relative `_nextPage()`
call to an **explicit navigation to page 4** (Profile Details).

**Before**:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_pageController.hasClients) {
    _nextPage(); // Relative navigation - could be affected by page rebuilds
  }
});
```

**After**:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_pageController.hasClients) {
    debugPrint('Navigating to page 4 (Profile Details - Nickname & DOB)');
    _pageController.animateToPage(
      4, // Explicit: Profile Details step (nickname + DOB)
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
});
```

## Why This Works

The explicit page index ensures that:

- Regardless of the current pages array state
- Regardless of whether the user is male or female
- Regardless of any rebuild race conditions

The app will **always** navigate to page 4 (Profile Details) after gender
selection, forcing users to enter their nickname and date of birth manually.

## Related Changes

This fix works in conjunction with the authentication-only Google sign-in (see
`.agent/google_auth_only.md`):

- Google sign-in creates profile with minimal data (email only)
- No auto-fill of name, photo, or other details from Google account
- Users must manually complete all profile fields during signup

## Testing Checklist

- [ ] Google sign-up → Gender selection → **Should go to Nickname & DOB page**
- [ ] Male users: After entering details → Go to main app
- [ ] Female users: After entering details → Go to photo verification → Go to
      main app
- [ ] Email sign-up flow still works normally
