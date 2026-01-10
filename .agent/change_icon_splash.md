# Changing App Icon and Splash Screen

## 📱 Current Status

Right now your app has:
- ✅ **App Icon**: Default Flutter logo
- ✅ **App Name**: "bestie" (shown on home screen)
- ⚠️ **Splash Screen**: Default Flutter white screen

Let's change these to your own branding!

---

## 🎨 Option 1: Quick Fix (Easiest - Recommended)

### **Step 1: Prepare Your Logo**

You need:
- ✅ 1 image file (PNG with transparent background)
- ✅ Size: At least **512x512 pixels**
- ✅ Square shape
- ✅ Simple design (looks good when small)

Save it as: `assets/icon/app_icon.png`

---

### **Step 2: Install Icon Generator**

Add this to `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  flutter_launcher_icons: ^0.13.1  # ← Add this
```

---

### **Step 3: Configure Icon Generator**

Add this at the **end** of `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#FFFFFF"  # Your brand color
  adaptive_icon_foreground: "assets/icon/app_icon.png"
```

**Colors you might want:**
- Lime/Green theme: `"#65A30D"` or `"#84CC16"`
- Pink theme: `"#EC4899"`
- Purple theme: `"#A855F7"`
- White: `"#FFFFFF"`

---

### **Step 4: Generate Icons**

```bash
# Install the package
flutter pub get

# Generate all icon sizes
flutter pub run flutter_launcher_icons
```

**Output:**
```
✓ Creating icons for Android
✓ Generated launcher icons for Android
```

Done! 🎉

---

## 🌅 Adding a Splash Screen

### **Step 1: Install Splash Screen Package**

Add to `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  # ... existing packages
  flutter_native_splash: ^2.4.0  # ← Add this
```

---

### **Step 2: Prepare Splash Image**

Create a splash screen logo:
- ✅ Size: **1242x2688 pixels** (will be scaled)
- ✅ PNG with transparent background
- ✅ Centered logo (simple design)

Save it as: `assets/icon/splash_logo.png`

---

### **Step 3: Configure Splash Screen**

Add this at the **end** of `pubspec.yaml`:

```yaml
flutter_native_splash:
  color: "#FFFFFF"  # Background color
  image: assets/icon/splash_logo.png  # Your logo
  android: true
  ios: false
  
  # Optional: Different background for dark mode
  color_dark: "#000000"
  image_dark: assets/icon/splash_logo.png
```

**Recommended Colors:**
- Light mode: `"#FFFFFF"` (white)
- Dark mode: `"#000000"` (black)
- Or use your brand color

---

### **Step 4: Generate Splash Screen**

```bash
# Install the package
flutter pub get

# Generate splash screen
dart run flutter_native_splash:create
```

**Output:**
```
✓ Creating splash screens for Android
✓ Splash screen successfully generated
```

---

## 🎯 Complete Setup (All Steps)

Here's the complete workflow:

### **1. Create Asset Folder**

```bash
mkdir assets\icon
```

### **2. Add Images**
- `assets/icon/app_icon.png` (512x512, square logo)
- `assets/icon/splash_logo.png` (1242x2688, centered logo)

### **3. Update `pubspec.yaml`**

```yaml
name: bestie
description: "A new Flutter project."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.10.3

dependencies:
  # ... all your existing dependencies

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  flutter_launcher_icons: ^0.13.1  # ← NEW
  flutter_native_splash: ^2.4.0    # ← NEW

flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/images/
    - assets/images/icons/
    - assets/sounds/
    - assets/icon/  # ← NEW: Add this line

# ← ADD THIS SECTION
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#65A30D"  # Your brand color
  adaptive_icon_foreground: "assets/icon/app_icon.png"

# ← ADD THIS SECTION
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/icon/splash_logo.png
  android: true
  ios: false
  android_12:
    color: "#FFFFFF"
    image: assets/icon/splash_logo.png
```

### **4. Run Generators**

```bash
# Get packages
flutter pub get

# Generate icons
flutter pub run flutter_launcher_icons

# Generate splash screen
dart run flutter_native_splash:create

# Clean and rebuild
flutter clean
flutter build apk --release
```

---

## 🎨 Option 2: Manual Method (More Control)

If you don't want to use packages:

### **App Icon (Manual)**

1. **Generate icons** using: https://icon.kitchen/ or https://appicon.co/
2. **Download** the generated files
3. **Replace** files in these folders:
   ```
   android/app/src/main/res/mipmap-mdpi/
   android/app/src/main/res/mipmap-hdpi/
   android/app/src/main/res/mipmap-xhdpi/
   android/app/src/main/res/mipmap-xxhdpi/
   android/app/src/main/res/mipmap-xxxhdpi/
   ```

### **Splash Screen (Manual)**

1. Create `android/app/src/main/res/drawable/launch_background.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_color" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash_logo" />
    </item>
</layer-list>
```

2. Add your logo as `android/app/src/main/res/drawable/splash_logo.png`

3. Add color in `android/app/src/main/res/values/colors.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="splash_color">#FFFFFF</color>
</resources>
```

---

## ✅ Testing Your Changes

### **Test Icon**
```bash
flutter clean
flutter build apk --debug
flutter install
```

Look at your phone's app drawer - you should see your new icon!

### **Test Splash Screen**
1. Close the app completely
2. Open it again
3. You should see your splash screen for 1-2 seconds

---

## 🎨 Design Tips

### **App Icon**
- ✅ **Keep it simple** - looks good when small
- ✅ **High contrast** - easy to recognize
- ✅ **Unique colors** - stands out on home screen
- ✅ **No text** - hard to read when small
- ❌ **Avoid photos** - look bad when scaled

### **Splash Screen**
- ✅ **Centered logo** - safe area for all screens
- ✅ **Solid background** - fast to load
- ✅ **Match theme** - use brand colors
- ✅ **Keep it simple** - shown for 1-2 seconds only
- ❌ **Avoid gradients** - can look different on devices

---

## 🚀 Quick Commands Reference

```bash
# After setting up pubspec.yaml and adding images:

# Install packages
flutter pub get

# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screen
dart run flutter_native_splash:create

# Clean and rebuild
flutter clean
flutter build apk --release

# Test on device
flutter install
```

---

## 🎯 Recommended Setup

For the **Bestie** app, I'd suggest:

**App Icon:**
- Lime green background (`#65A30D`)
- White heart or chat icon in center
- Simple, modern design

**Splash Screen:**
- White background (`#FFFFFF`)
- Lime green logo in center
- App name "Bestie" below logo (optional)

---

## 📝 Checklist

Before building your APK:

- [ ] Created `assets/icon/` folder
- [ ] Added `app_icon.png` (512x512)
- [ ] Added `splash_logo.png` (optional, for splash)
- [ ] Updated `pubspec.yaml` with icon/splash config
- [ ] Ran `flutter pub get`
- [ ] Ran `flutter pub run flutter_launcher_icons`
- [ ] Ran `dart run flutter_native_splash:create` (if using splash)
- [ ] Tested on device
- [ ] Built release APK

---

## 🎉 That's It!

Your app will now have:
- ✅ Custom app icon (no more Flutter logo!)
- ✅ Custom splash screen (branded experience!)
- ✅ Professional look and feel!

Need help with the design? Let me know! 🎨
