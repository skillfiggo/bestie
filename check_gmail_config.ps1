# Gmail Sign-In Diagnostic Script (PowerShell)
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Gmail Sign-In Diagnostic Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: Not in Flutter project root" -ForegroundColor Red
    Write-Host "Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter project detected" -ForegroundColor Green
Write-Host ""

# Check google-services.json
Write-Host "📄 Checking google-services.json..." -ForegroundColor Cyan
if (Test-Path "android/app/google-services.json") {
    Write-Host "✅ google-services.json found" -ForegroundColor Green
    
    $json = Get-Content "android/app/google-services.json" | ConvertFrom-Json
    $projectId = $json.project_info.project_id
    $packageName = $json.client[0].client_info.android_client_info.package_name
    
    Write-Host "   Project ID: $projectId" -ForegroundColor White
    Write-Host "   Package Name: $packageName" -ForegroundColor White
    
    # Count OAuth clients
    $androidClients = $json.client[0].oauth_client | Where-Object { $_.client_type -eq 1 }
    $webClient = $json.client[0].oauth_client | Where-Object { $_.client_type -eq 3 }
    
    $androidCount = ($androidClients | Measure-Object).Count
    $webClientId = $webClient.client_id
    
    Write-Host "   Android OAuth Clients (Type 1): $androidCount" -ForegroundColor White
    Write-Host "   Web Client ID (Type 3): $webClientId" -ForegroundColor White
    
    if ($androidCount -eq 1) {
        Write-Host "   ⚠️  WARNING: Only 1 Android client found!" -ForegroundColor Yellow
        Write-Host "   This likely means you only have DEBUG or RELEASE SHA-1, not both" -ForegroundColor Yellow
        Write-Host "   Expected: 2+ Android clients (one for each SHA-1)" -ForegroundColor Yellow
        
        # Show the certificate hash
        $certHash = $androidClients[0].android_info.certificate_hash
        Write-Host "   Current SHA-1: $certHash" -ForegroundColor White
    } else {
        Write-Host "   ✅ $androidCount Android clients found (good)" -ForegroundColor Green
        
        # Show all certificate hashes
        foreach ($client in $androidClients) {
            $hash = $client.android_info.certificate_hash
            Write-Host "   SHA-1: $hash" -ForegroundColor White
        }
    }
} else {
    Write-Host "❌ google-services.json NOT FOUND in android/app/" -ForegroundColor Red
    Write-Host "   Please download it from Firebase Console" -ForegroundColor Red
}
Write-Host ""

# Check .env file
Write-Host "🔧 Checking .env configuration..." -ForegroundColor Cyan
if (Test-Path ".env") {
    Write-Host "✅ .env file found" -ForegroundColor Green
    
    $envContent = Get-Content ".env"
    $googleClientLine = $envContent | Where-Object { $_ -match "GOOGLE_WEB_CLIENT_ID" }
    
    if ($googleClientLine) {
        $envClientId = ($googleClientLine -split "=")[1].Trim()
        Write-Host "   GOOGLE_WEB_CLIENT_ID: $envClientId" -ForegroundColor White
        
        # Check if it matches
        if ($envClientId -eq $webClientId) {
            Write-Host "   ✅ Matches Web Client ID in google-services.json" -ForegroundColor Green
        } else {
            Write-Host "   ❌ MISMATCH with google-services.json Web Client ID!" -ForegroundColor Red
            Write-Host "   .env has: $envClientId" -ForegroundColor Red
            Write-Host "   google-services.json has: $webClientId" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ GOOGLE_WEB_CLIENT_ID not found in .env" -ForegroundColor Red
    }
} else {
    Write-Host "❌ .env file NOT FOUND" -ForegroundColor Red
}
Write-Host ""

# Check Android build configuration
Write-Host "🤖 Checking Android configuration..." -ForegroundColor Cyan
if (Test-Path "android/app/build.gradle.kts") {
    Write-Host "✅ build.gradle.kts found" -ForegroundColor Green
    
    $buildContent = Get-Content "android/app/build.gradle.kts"
    
    if ($buildContent -match "com.google.gms.google-services") {
        Write-Host "   ✅ Google Services plugin applied" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Google Services plugin NOT applied!" -ForegroundColor Red
    }
    
    # Check package name
    $appIdLine = $buildContent | Where-Object { $_ -match "applicationId" }
    if ($appIdLine) {
        $buildPackage = ($appIdLine -split '"')[1]
        Write-Host "   Application ID: $buildPackage" -ForegroundColor White
        
        if ($buildPackage -eq $packageName) {
            Write-Host "   ✅ Package name matches google-services.json" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Package name MISMATCH!" -ForegroundColor Red
        }
    }
}
Write-Host ""

# Check key.properties for release signing
Write-Host "🔐 Checking signing configuration..." -ForegroundColor Cyan
if (Test-Path "android/app/key.properties") {
    Write-Host "✅ key.properties found (release signing configured)" -ForegroundColor Green
} else {
    Write-Host "⚠️  key.properties NOT found (no release signing configured)" -ForegroundColor Yellow
}
Write-Host ""

# Get SHA-1 fingerprints
Write-Host "🔐 Getting SHA-1 fingerprints..." -ForegroundColor Cyan
Write-Host "   Running gradlew signingReport..." -ForegroundColor White
Write-Host ""

Push-Location android
try {
    $signingReport = & ./gradlew.bat signingReport 2>&1
    
    # Extract debug SHA-1
    Write-Host "   --- Debug Certificate ---" -ForegroundColor Yellow
    $debugSection = $signingReport | Select-String -Pattern "Variant: debug" -Context 0,10
    if ($debugSection) {
        $debugSHA1 = $debugSection.Context.PostContext | Select-String -Pattern "SHA1:"
        if ($debugSHA1) {
            Write-Host $debugSHA1 -ForegroundColor White
        }
    } else {
        Write-Host "   ⚠️  Could not retrieve debug SHA-1" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Extract release SHA-1
    Write-Host "   --- Release Certificate ---" -ForegroundColor Yellow
    $releaseSection = $signingReport | Select-String -Pattern "Variant: release" -Context 0,10
    if ($releaseSection) {
        $releaseSHA1 = $releaseSection.Context.PostContext | Select-String -Pattern "SHA1:"
        if ($releaseSHA1) {
            Write-Host $releaseSHA1 -ForegroundColor White
        }
    } else {
        Write-Host "   ⚠️  Could not retrieve release SHA-1" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Error running gradlew: $_" -ForegroundColor Red
} finally {
    Pop-Location
}
Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "📋 SUMMARY & RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Copy ALL SHA-1 fingerprints shown above" -ForegroundColor White
Write-Host "2. Go to Firebase Console → Project Settings" -ForegroundColor White
Write-Host "3. Add ALL SHA-1 fingerprints to your Android app" -ForegroundColor White
Write-Host "4. Download the NEW google-services.json" -ForegroundColor White
Write-Host "5. Replace android/app/google-services.json" -ForegroundColor White
Write-Host "6. Make sure .env has the correct GOOGLE_WEB_CLIENT_ID (Type 3)" -ForegroundColor White
Write-Host "7. Run: flutter clean && flutter pub get" -ForegroundColor White
Write-Host "8. Rebuild and test" -ForegroundColor White
Write-Host ""

Write-Host "For detailed troubleshooting, see:" -ForegroundColor Cyan
Write-Host ".agent/gmail_signin_troubleshooting.md" -ForegroundColor Cyan
Write-Host ""
