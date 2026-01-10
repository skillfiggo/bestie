# Building APK for Distribution

## 🎯 Quick Start (Test Build)

If you just want a quick APK to test:

```bash
# Navigate to your project
cd c:\Users\admin\bestie\bestie

# Build APK (debug version)
flutter build apk --debug

# APK will be at: build\app\outputs\flutter-apk\app-debug.apk
```

---

## 🚀 Production Build (Recommended)

For a proper release that users can install:

### **Step 1: Update App Information**

#### Edit `android/app/build.gradle`

Find and update these values:

```gradle
android {
    defaultConfig {
        applicationId "com.bestie.app"  // Your unique app ID
        minSdkVersion 21                // Minimum Android version
        targetSdkVersion 34              // Target Android version
        versionCode 1                    // Increment for each release
        versionName "1.0.0"             // Display version
    }
}
```

**Important:**
- `versionCode`: Must increase with each update (1, 2, 3...)
- `versionName`: User-facing version (1.0.0, 1.0.1, 1.1.0...)

---

### **Step 2: Set Up App Signing (Required for Play Store)**

#### Create a Keystore

```powershell
# Run this in PowerShell
cd android\app

keytool -genkey -v -keystore bestie-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bestie

# You'll be asked for:
# - Password (REMEMBER THIS!)
# - Your name
# - Organization name
# - City, State, Country
```

**⚠️ IMPORTANT:** Save the password somewhere secure! You'll need it for every release.

---

#### Create `android/key.properties`

Create this file with your keystore details:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=bestie
storeFile=app/bestie-keystore.jks
```

**Add to `.gitignore`:**
```
android/key.properties
android/app/*.jks
```

---

#### Update `android/app/build.gradle`

Add this BEFORE the `android {` block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

### **Step 3: Update App Icon (Optional)**

Replace the default icon:

1. **Get an icon** (512x512 PNG)
2. **Use a generator**: https://icon.kitchen/ or https://romannurik.github.io/AndroidAssetStudio/
3. **Replace files** in `android/app/src/main/res/mipmap-*` folders

Or use `flutter_launcher_icons` package (easier):

```yaml
# Add to pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
```

Then run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

---

### **Step 4: Update App Name**

#### Edit `android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="Bestie"  <!-- Change this to your app name -->
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

---

### **Step 5: Build APK**

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

**Output location:**
```
build\app\outputs\flutter-apk\app-release.apk
```

---

### **Step 6: Build App Bundle (For Play Store)**

If you're publishing to Google Play Store, use AAB instead:

```bash
flutter build appbundle --release
```

**Output:**
```
build\app\outputs\bundle\release\app-release.aab
```

---

## 📦 **Build Options**

### **Split APKs by Architecture (Smaller Size)**

```bash
flutter build apk --release --split-per-abi
```

This creates 3 APKs:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM) ← Most common
- `app-x86_64-release.apk` (Intel/AMD devices)

Users only download the one for their device (smaller size).

---

### **Obfuscate Code (Security)**

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

This makes reverse-engineering harder.

---

## 📱 **Testing Your APK**

### **Test on Physical Device**

```bash
# Install on connected device
flutter install --release

# Or manually:
adb install build\app\outputs\flutter-apk\app-release.apk
```

### **Test on Emulator**

```bash
# Start emulator
flutter emulators --launch <emulator_id>

# Install APK
flutter install build\app\outputs\flutter-apk\app-release.apk
```

---

## 🌐 **Distribution Options**

### **Option 1: Direct Download (Fastest)**

1. Upload `app-release.apk` to:
   - **Google Drive** (set to "Anyone with link can view")
   - **Dropbox**
   - **Your own website**
   - **GitHub Releases**

2. Share the link with users

3. Users must:
   - Enable "Install from Unknown Sources"
   - Download and tap to install

---

### **Option 2: Google Play Store (Recommended)**

**Pros:**
- ✅ Trusted by users
- ✅ Automatic updates
- ✅ Better visibility

**Cons:**
- ❌ $25 one-time fee
- ❌ Approval process (can take days)
- ❌ More requirements

**Steps:**
1. Create Google Play Console account
2. Upload `app-release.aab`
3. Fill in store listing
4. Submit for review

---

### **Option 3: Alternative App Stores**

- **APKPure**: Free, no review
- **Amazon Appstore**: Good for Fire devices
- **Samsung Galaxy Store**: Pre-installed on Samsung devices
- **Huawei AppGallery**: For Huawei devices

---

## ✅ **Pre-Release Checklist**

Before distributing:

- [ ] Test APK on multiple devices
- [ ] Verify all features work
- [ ] Check Supabase connection works
- [ ] Test payment flows
- [ ] Verify permissions are requested correctly
- [ ] Test on different Android versions (min API 21+)
- [ ] Check app size is reasonable (< 50MB is good)
- [ ] Ensure no debug/test code remains
- [ ] Update privacy policy URL
- [ ] Prepare app store screenshots (if using Play Store)

---

## 🔧 **Troubleshooting**

### **"Unsigned APK" Warning**

If you get this, you didn't set up signing correctly. Review Step 2.

### **APK Too Large**

```bash
# Use split APKs
flutter build apk --release --split-per-abi

# Or use AAB for Play Store (automatically optimized)
flutter build appbundle --release
```

### **Build Fails**

```bash
# Clean and retry
flutter clean
flutter pub get
flutter build apk --release
```

### **"Install Blocked" on Phone**

Enable "Install from Unknown Sources" in phone settings.

---

## 📊 **APK Size Optimization**

Typical sizes:
- **Debug APK**: 50-100 MB
- **Release APK**: 20-40 MB
- **Split APK (arm64)**: 15-25 MB
- **App Bundle**: Automatic optimization

To reduce size:
1. Use `--split-per-abi`
2. Remove unused assets
3. Optimize images
4. Use AAB for Play Store

---

## 🎉 **Quick Commands Reference**

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for distribution)
flutter build apk --release

# Split APKs (smaller size)
flutter build apk --release --split-per-abi

# App Bundle (for Play Store)
flutter build appbundle --release

# Install on device
flutter install --release

# Check APK size
dir build\app\outputs\flutter-apk\
```

---

## 🚀 **Recommended First Build**

For your first public release:

```bash
# 1. Clean everything
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build optimized APK
flutter build apk --release --split-per-abi

# 4. Your APKs will be in:
# build\app\outputs\flutter-apk\
```

Share the **arm64-v8a** version (works on 90%+ of devices).

---

## 📝 **Next Steps**

1. ✅ Build your first APK
2. ✅ Test it thoroughly
3. ✅ Set up proper signing for future releases
4. ✅ Choose distribution method
5. ✅ Share with users!

Good luck! 🎊
