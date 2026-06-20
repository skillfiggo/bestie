#!/bin/bash

echo "========================================="
echo "Gmail Sign-In Diagnostic Script"
echo "========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not in Flutter project root"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "✅ Flutter project detected"
echo ""

# Check google-services.json
echo "📄 Checking google-services.json..."
if [ -f "android/app/google-services.json" ]; then
    echo "✅ google-services.json found"
    
    # Extract key information
    PROJECT_ID=$(grep -o '"project_id"[[:space:]]*:[[:space:]]*"[^"]*"' android/app/google-services.json | cut -d'"' -f4)
    PACKAGE_NAME=$(grep -o '"package_name"[[:space:]]*:[[:space:]]*"[^"]*"' android/app/google-services.json | head -1 | cut -d'"' -f4)
    
    echo "   Project ID: $PROJECT_ID"
    echo "   Package Name: $PACKAGE_NAME"
    
    # Count OAuth clients
    OAUTH_COUNT=$(grep -c '"client_type"[[:space:]]*:[[:space:]]*1' android/app/google-services.json)
    WEB_CLIENT=$(grep -A 1 '"client_type"[[:space:]]*:[[:space:]]*3' android/app/google-services.json | grep '"client_id"' | cut -d'"' -f4)
    
    echo "   Android OAuth Clients (Type 1): $OAUTH_COUNT"
    echo "   Web Client ID (Type 3): $WEB_CLIENT"
    
    if [ "$OAUTH_COUNT" -eq 1 ]; then
        echo "   ⚠️  WARNING: Only 1 Android client found!"
        echo "   This likely means you only have DEBUG or RELEASE SHA-1, not both"
        echo "   Expected: 2+ Android clients (one for each SHA-1)"
    else
        echo "   ✅ Multiple Android clients found (good)"
    fi
else
    echo "❌ google-services.json NOT FOUND in android/app/"
    echo "   Please download it from Firebase Console"
fi
echo ""

# Check .env file
echo "🔧 Checking .env configuration..."
if [ -f ".env" ]; then
    echo "✅ .env file found"
    
    if grep -q "GOOGLE_WEB_CLIENT_ID" .env; then
        ENV_CLIENT_ID=$(grep "GOOGLE_WEB_CLIENT_ID" .env | cut -d'=' -f2 | tr -d ' ')
        echo "   GOOGLE_WEB_CLIENT_ID: $ENV_CLIENT_ID"
        
        # Check if it matches the web client from google-services.json
        if [ "$ENV_CLIENT_ID" = "$WEB_CLIENT" ]; then
            echo "   ✅ Matches Web Client ID in google-services.json"
        else
            echo "   ❌ MISMATCH with google-services.json Web Client ID!"
            echo "   .env has: $ENV_CLIENT_ID"
            echo "   google-services.json has: $WEB_CLIENT"
        fi
    else
        echo "   ❌ GOOGLE_WEB_CLIENT_ID not found in .env"
    fi
else
    echo "❌ .env file NOT FOUND"
fi
echo ""

# Check Android build configuration
echo "🤖 Checking Android configuration..."
if [ -f "android/app/build.gradle.kts" ]; then
    echo "✅ build.gradle.kts found"
    
    if grep -q "com.google.gms.google-services" android/app/build.gradle.kts; then
        echo "   ✅ Google Services plugin applied"
    else
        echo "   ❌ Google Services plugin NOT applied!"
    fi
    
    # Check package name
    BUILD_PACKAGE=$(grep "applicationId" android/app/build.gradle.kts | cut -d'"' -f2)
    echo "   Application ID: $BUILD_PACKAGE"
    
    if [ "$BUILD_PACKAGE" = "$PACKAGE_NAME" ]; then
        echo "   ✅ Package name matches google-services.json"
    else
        echo "   ❌ Package name MISMATCH!"
    fi
else
    echo "⚠️  build.gradle.kts not found (checking build.gradle)"
    if [ -f "android/app/build.gradle" ]; then
        echo "✅ build.gradle found"
    fi
fi
echo ""

# Get SHA-1 fingerprints
echo "🔐 Getting SHA-1 fingerprints..."
echo ""
echo "   --- Debug Certificate ---"
cd android
if ./gradlew signingReport 2>/dev/null | grep -A 2 "Variant: debug" | grep "SHA1:"; then
    ./gradlew signingReport 2>/dev/null | grep -A 2 "Variant: debug" | grep "SHA1:"
else
    echo "   ⚠️  Could not retrieve debug SHA-1"
fi
cd ..

echo ""
echo "   --- Release Certificate ---"
if [ -f "android/app/key.properties" ]; then
    echo "   ✅ key.properties found (release signing configured)"
    cd android
    if ./gradlew signingReport 2>/dev/null | grep -A 2 "Variant: release" | grep "SHA1:"; then
        ./gradlew signingReport 2>/dev/null | grep -A 2 "Variant: release" | grep "SHA1:"
    else
        echo "   ⚠️  Could not retrieve release SHA-1"
    fi
    cd ..
else
    echo "   ⚠️  key.properties NOT found (no release signing configured)"
fi
echo ""

# Summary and recommendations
echo "========================================="
echo "📋 SUMMARY & RECOMMENDATIONS"
echo "========================================="
echo ""

echo "Next steps:"
echo "1. Copy ALL SHA-1 fingerprints shown above"
echo "2. Go to Firebase Console → Project Settings"
echo "3. Add ALL SHA-1 fingerprints to your Android app"
echo "4. Download the NEW google-services.json"
echo "5. Replace android/app/google-services.json"
echo "6. Make sure .env has the correct GOOGLE_WEB_CLIENT_ID (Type 3)"
echo "7. Run: flutter clean && flutter pub get"
echo "8. Rebuild and test"
echo ""

echo "For detailed troubleshooting, see:"
echo ".agent/gmail_signin_troubleshooting.md"
echo ""
