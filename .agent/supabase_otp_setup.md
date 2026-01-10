# Supabase OTP Configuration for Password Reset

## Problem
Password reset was sending a reset **link** instead of a 6-digit **OTP code**.

## Solution Applied
Changed `auth_repository.dart` to use `signInWithOtp()` with type 'recovery' instead of `resetPasswordForEmail()`.

## Required Supabase Dashboard Configuration

To ensure the OTP emails are sent correctly, you need to configure your Supabase Email Templates:

### Steps:

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Email Templates**
   - Click on `Authentication` in the left sidebar
   - Click on `Email Templates`

3. **Configure the "Magic Link" Template**
   - Find the template called "Magic Link" or "Confirm signup"
   - Make sure it contains the token variable: `{{ .Token }}`
   - This template will be used for sending the 6-digit OTP

4. **Verify Email Settings**
   - Go to `Authentication` → `Settings`
   - Scroll to "Email Auth"
   - Ensure "Enable Email Confirmations" is enabled
   - Make sure your SMTP settings are configured (or use Supabase's default)

### Default Template Should Look Like:
```html
<h2>Reset Your Password</h2>
<p>Your verification code is:</p>
<h1>{{ .Token }}</h1>
<p>This code will expire in 60 minutes.</p>
```

## Testing

1. **Test the flow**:
   - Enter your email on the Forgot Password screen
   - Check your email for a 6-digit code (not a link)
   - Enter the code and new password on the Reset Password screen
   - Verify you can login with the new password

## Code Changes Made

### `auth_repository.dart`
```dart
Future<void> resetPassword(String email) async {
  try {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: null,
      shouldCreateUser: false,
      data: {'type': 'recovery'},
    );
  } catch (e) {
    throw Exception('Failed to send reset code. Please check your email and try again.');
  }
}
```

This change ensures:
- A 6-digit OTP is sent instead of a link
- The OTP type is 'recovery' for password reset
- The user won't be created if they don't exist (`shouldCreateUser: false`)
