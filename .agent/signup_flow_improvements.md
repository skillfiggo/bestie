# Signup Flow Improvements

## Overview
Enhanced the signup flow to prevent users from going back after email verification and to automatically resume signup from where they stopped if they leave or close the app.

## Changes Made

### 1. Prevent Back Navigation After Email Verification

#### SignupScreen (`lib/features/auth/presentation/screens/signup_screen.dart`)

**Back Button Visibility:**
- Back button is now **only visible on step 0** (Email entry)
- Once OTP is verified (`_otpVerified = true`), the back button is **hidden**
- "Sign In" text button is also hidden after OTP verification

**PopScope Handling:**
- System back button is disabled after OTP verification
- Users cannot swipe back or use device back button once email is verified

```dart
// Back button condition
if (!_otpVerified && currentPage == 0)
  IconButton(...)
  
// PopScope condition  
if (_otpVerified || currentPage > 1) {
  return; // Block navigation
}
```

### 2. Resume Signup From Last Completed Step

#### SignupScreen - Enhanced initState()

The signup screen now checks the user's profile status on initialization and resumes from the appropriate step:

**Profile Status Checks:**
1. **Has User?** → Check if authenticated
2. **Profile Status** → Check `status` field (`pending_profile`, `incomplete`)
3. **Password Set?** → Check if password exists or Google login
4. **Gender Selected?** → Check if gender is set (not null, empty, or 'other')
5. **Name Provided?** → Check if name is set (not 'New User')
6. **Female Verification?** → Check if female user has uploaded verification photo

**Resume Logic:**
```dart
if (status == 'pending_profile' || status == 'incomplete') {
  setState(() { _otpVerified = true; });
  
  if (!hasPassword) {
    // Resume at Password step (Step 2)
    _pageController.jumpToPage(2);
  } else if (gender == null || gender.isEmpty) {
    // Resume at Gender selection (Step 3)
    _pageController.jumpToPage(3);
  } else if (name == null || name.isEmpty) {
    // Resume at Profile Details (Step 4)
    _pageController.jumpToPage(4);
  } else if (gender == 'female' && no verification photo) {
    // Resume at Female Verification (Step 5)
    _pageController.jumpToPage(5);
  }
}
```

#### SplashView - Profile Status Check

Updated splash screen to check signup completion before routing:

**Navigation Logic:**
1. Get current session
2. If authenticated → Check profile status
3. If incomplete signup → Route to Auth view with signup page (argument: 1)
4. If complete → Route to Main Shell

**Incomplete Signup Indicators:**
- `status == 'pending_profile'`
- `status == 'incomplete'`
- `gender == null || gender.isEmpty || gender == 'other'`
- `name == null || name.isEmpty || name == 'New User'`

```dart
if (incomplete signup detected) {
  Navigator.pushReplacementNamed(
    context, 
    AppRouter.auth, 
    arguments: 1  // Open signup page
  );
}
```

## Signup Flow Steps

| Step | Page | Can Go Back? | Resume Condition |
|------|------|--------------|------------------|
| 0 | Email Entry | ✅ Yes | User not authenticated |
| 1 | OTP Verification | ❌ No | Email sent but not verified |
| 2 | Password | ❌ No | Profile exists but no password |
| 3 | Gender Selection | ❌ No | Password set but no gender |
| 4 | Profile Details | ❌ No | Gender set but incomplete profile |
| 5 | Female Verification | ❌ No | Female with incomplete verification |

## User Experience Improvements

### Before
- ❌ Users could go back and abandon signup mid-way
- ❌ Users had to start from scratch if they closed the app
- ❌ No way to track signup progress

### After
- ✅ Users are guided through complete signup once email is verified
- ✅ Users can close app and resume exactly where they left off
- ✅ Clear progress tracking via profile status
- ✅ Seamless experience for returning users

## Testing Scenarios

### Scenario 1: User Enters Email
1. User enters email
2. Clicks "Send Code"
3. **Closes app**
4. **Reopens app** → Splash → Auth (Login page shown)
5. User must restart signup

### Scenario 2: User Verifies Email
1. User enters email and verifies OTP
2. Now on Password step
3. **Closes app**
4. **Reopens app** → Splash → Auth (Signup page, Password step)
5. User continues from Password step

### Scenario 3: User Sets Password
1. User completes email, OTP, and password
2. Now on Gender selection
3. **Closes app**
4. **Reopens app** → Splash → Auth (Signup page, Gender step)
5. User continues from Gender selection

### Scenario 4: Female User Verification
1. Female user completes all steps except photo verification
2. **Closes app**
3. **Reopens app** → Splash → Auth (Signup page, Photo Verification)
4. User uploads verification photo and completes signup

## Database Fields Used

- `status`: 'pending_profile', 'incomplete', 'active'
- `gender`: null, '', 'other', 'male', 'female'
- `name`: null, '', 'New User', or actual name
- `verification_photo_url`: null, '', or URL
- `encrypted_password`: Checked via user object

## Notes

- Users authenticated via Google (already have password from provider) skip password step
- All navigation is handled via `PageController.jumpToPage()` to avoid animation delays
- Profile status is checked both on signup screen init AND on splash screen
- Email is pre-populated from authenticated user if available
