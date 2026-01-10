# Google Sign-In Setup Guide

To activate Google Signup in your Bestie app, follow these steps:

## 1. Google Cloud Console Configuration

1.  Go to the [Google Cloud Console](https://console.cloud.google.com/).
2.  Create a new project (or select your existing one).
3.  Navigate to **APIs & Services > OAuth consent screen**.
    *   Choose **External**.
    *   Fill in the required app information (App name, support email, developer contact info).
    *   Add the `.../auth/v1/callback` URL from your Supabase project (see Step 2 below).
4.  Navigate to **APIs & Services > Credentials**.
5.  Click **Create Credentials > OAuth client ID**.
    *   **Web application**: Create one for Supabase (this will give you the Client ID and Client Secret for the Supabase Dashboard).
    *   **Android**: Create one for your Android app.
        *   Package name: `com.skillfiggo.bestie` (found in `android/app/build.gradle.kts`)
        *   SHA-1 certificate fingerprint: Run `./gradlew signingReport` in the `android` folder to get this.
    *   **iOS**: Create one for your iOS app.
        *   Bundle ID: `com.skillfiggo.bestie` (or your actual bundle ID).

## 2. Supabase Dashboard Configuration

1.  Go to your [Supabase Project Dashboard](https://supabase.com/dashboard).
2.  Navigate to **Authentication > Providers**.
3.  Find **Google** and toggle it **ON**.
4.  Enter the **Client ID** and **Client Secret** obtained from the "Web application" OAuth client ID in Google Cloud Console.
5.  Copy the **Redirect URI** provided by Supabase (e.g., `https://xxxx.supabase.co/auth/v1/callback`) and add it to the "Authorized redirect URIs" in your Google Cloud Web Client ID.
6.  Click **Save**.

## 3. Local Project Configuration

### Android
1.  In Google Cloud Console, for your Android Client ID, download the `google-services.json`.
2.  Place it in `bestie/android/app/`.

### iOS
1.  In Google Cloud Console, for your iOS Client ID, download the `GoogleService-Info.plist`.
2.  Add it to your Xcode project in the `Runner` folder.
3.  Add the URL scheme to `ios/Runner/Info.plist` (the `REVERSED_CLIENT_ID` from the plist).

### Environment Variables
Update your `.env` file (not committed to git) with the Client IDs if you want to use them via `String.fromEnvironment` (already implemented in `AuthRepository`):
```env
# Optional but recommended for specific environments
GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

## 4. Verification
1.  Restart your app: `flutter run`.
2.  On the Landing Screen, click the **Google** button.
3.  If configured correctly, you should see the Google Sign-In sheet.
