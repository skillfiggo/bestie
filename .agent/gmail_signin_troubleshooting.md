# Gmail Sign-In Troubleshooting Guide

## Current Configuration Summary

### google-services.json Analysis
**Location:** `android/app/google-services.json`

**Key Information:**
- **Project ID:** bestieechat
- **Package Name:** com.skillfiggo.bestie
- **SHA-1 Certificate Hash (Debug):** `6864b3cc506901a9436610a7b846d4389455d0d7`
- **Android Client ID (Type 1):** `845882768068-n08r8pamab43luhr554vkmtop4fih6u0.apps.googleusercontent.com`
- **Web Client ID (Type 3):** `845882768068-3ok8lo365geupr5kp5oipei8a7f5o6ds.apps.googleusercontent.com`

## ⚠️ Critical: Release SHA-1 vs Debug SHA-1

You mentioned setting up **Release SHA-1**, but the current `google-services.json` only contains the **Debug SHA-1**. This is likely the issue!

### Problem
- The `google-services.json` file shows only ONE SHA-1 certificate: `6864b3cc506901a9436610a7b846d4389455d0d7`
- This is likely your **Debug** certificate
- If you're testing with a **Release** build or signed APK, Google Sign-In will fail with `ApiException: 10`

## ✅ Solution Steps

### Step 1: Get BOTH SHA-1 Certificates

#### For Debug Certificate:
```bash
cd android
./gradlew signingReport
```

Look for the **debug** keystore SHA-1.

#### For Release Certificate:
```bash
keytool -list -v -keystore android/app/your-release-key.jks -alias your-key-alias
```

Or if using the default debug keystore for release:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Step 2: Add BOTH SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **bestieechat**
3. Click on **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Find your Android app: `com.skillfiggo.bestie`
6. Click **Add fingerprint** for EACH SHA-1:
   - Add **Debug SHA-1**
   - Add **Release SHA-1**
   - Add **SHA-256** if available (both debug and release)

### Step 3: Download Updated google-services.json

After adding ALL the SHA-1 certificates:
1. Click **Download google-services.json**
2. Replace the file at `android/app/google-services.json`
3. The new file should show MULTIPLE `oauth_client` entries (one for each SHA-1)

### Step 4: Update .env File

Make sure your `.env` file has the **CORRECT** Web Client ID:

```env
GOOGLE_WEB_CLIENT_ID=845882768068-3ok8lo365geupr5kp5oipei8a7f5o6ds.apps.googleusercontent.com
```

**Important:** This MUST be the client ID ending in `.apps.googleusercontent.com` (Type 3 - Web client)

### Step 5: Configure Supabase Dashboard

1. Go to **Supabase Dashboard** → **Authentication** → **Providers**
2. Enable **Google Provider**
3. Add **Authorized Client IDs:**
   ```
   845882768068-3ok8lo365geupr5kp5oipei8a7f5o6ds.apps.googleusercontent.com
   ```
4. This should match the `GOOGLE_WEB_CLIENT_ID` in your `.env` file

### Step 6: Clean and Rebuild

```bash
# Clean Flutter
flutter clean
flutter pub get

# Clean Android
cd android
./gradlew clean
cd ..

# Rebuild
flutter run --release  # Or whatever build type you're testing
```

## 🔍 Common Error Messages & Solutions

### Error: `ApiException: 10`
**Meaning:** Developer Error - SHA-1 mismatch
**Solution:** 
- Add the SHA-1 of the signing certificate you're using to Firebase Console
- Download updated `google-services.json`
- Make sure you added the correct SHA-1 for the build type (debug vs release)

### Error: `Unacceptable audience in id_token`
**Meaning:** The Web Client ID in `.env` doesn't match what's in Supabase
**Solution:**
- Verify `GOOGLE_WEB_CLIENT_ID` in `.env` matches the Web client ID (Type 3) from `google-services.json`
- Verify same ID is added to Supabase Dashboard under Google Provider
- Both should end in `.apps.googleusercontent.com`

### Error: `PlatformException(sign_in_failed)`
**Meaning:** Google Sign-In configuration issue
**Solution:**
- Make sure `google-services.json` is in `android/app/` directory
- Verify package name matches everywhere: `com.skillfiggo.bestie`
- Check that Google Services plugin is applied in `android/app/build.gradle`

### Error: `No ID Token found`
**Meaning:** ID Token not returned by Google
**Solution:**
- The Web Client ID (serverClientId) must be correct
- Check `.env` file has the right `GOOGLE_WEB_CLIENT_ID`
- Make sure it's the Type 3 (Web) client ID, not the Android client ID

## 📋 Verification Checklist

- [ ] **Both** Debug and Release SHA-1 added to Firebase Console
- [ ] Downloaded **latest** `google-services.json` after adding SHA-1s
- [ ] `google-services.json` is in `android/app/` directory
- [ ] `.env` file contains `GOOGLE_WEB_CLIENT_ID` (Type 3 - ends in `.com`)
- [ ] Supabase Google Provider has the **same** Web Client ID
- [ ] Package name is `com.skillfiggo.bestie` everywhere
- [ ] Ran `flutter clean` and rebuilt the app
- [ ] Testing with the correct build type (if you added Release SHA-1, test with release build)

## 🧪 Testing Steps

### 1. Enable Debug Logging
The code already has debug logging. Run the app and check logs:

```bash
flutter run --verbose
```

Look for these debug messages:
```
Initializing Google Sign-In...
Web Client ID: found
Attempting googleSignIn.signIn()...
Google Auth successful. ID Token: found, Access Token: found
Signing in to Supabase with ID Token...
```

### 2. Test Debug Build
```bash
flutter run
```
Click on "Continue with Google" and watch the logs.

### 3. Test Release Build
```bash
flutter run --release
```
This uses the release signing certificate.

## 🔧 Quick Fix Commands

```bash
# Get Debug SHA-1
cd android
./gradlew signingReport | grep SHA1
cd ..

# Clean everything
flutter clean
cd android
./gradlew clean
cd ..

# Get dependencies
flutter pub get

# Run with logs
flutter run --verbose
```

## 📝 Expected google-services.json Structure (After Fix)

After adding both Debug and Release SHA-1, your `oauth_client` section should look like:

```json
"oauth_client": [
  {
    "client_id": "YOUR-ANDROID-CLIENT-DEBUG.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.skillfiggo.bestie",
      "certificate_hash": "YOUR_DEBUG_SHA1"
    }
  },
  {
    "client_id": "YOUR-ANDROID-CLIENT-RELEASE.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.skillfiggo.bestie",
      "certificate_hash": "YOUR_RELEASE_SHA1"
    }
  },
  {
    "client_id": "845882768068-3ok8lo365geupr5kp5oipei8a7f5o6ds.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

## 🎯 Most Likely Issue

Based on your situation (just added Release SHA-1), the problem is:
1. You added Release SHA-1 to Firebase Console ✅
2. But you **didn't download** the updated `google-services.json` ❌
3. Or you downloaded it but the app is using a **cached version** ❌

**Immediate Fix:**
1. Download the **latest** `google-services.json` from Firebase Console
2. Replace `android/app/google-services.json`
3. Run `flutter clean`
4. Run `flutter pub get`
5. Rebuild and test

## 📞 Need More Help?

If still not working, please provide:
1. The **exact error message** from logs
2. Which build type you're testing (debug or release)
3. Confirm you downloaded the latest `google-services.json` after adding Release SHA-1
4. Confirm the `GOOGLE_WEB_CLIENT_ID` in your `.env` file
