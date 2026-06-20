# App Versioning Guide

This guide explains how to manage version numbers for the Bestie app.

## Understanding Version Numbers

The app version follows **Semantic Versioning** (SemVer) with a build number:

```
version: MAJOR.MINOR.PATCH+BUILD
Example: version: 1.2.3+5
```

- **MAJOR**: Breaking changes (1.0.0 → 2.0.0)
- **MINOR**: New features, backward compatible (1.0.0 → 1.1.0)
- **PATCH**: Bug fixes, patches (1.0.0 → 1.0.1)
- **BUILD**: Internal build number, auto-incremented

## Quick Start

### Using the Automation Script

Run this from the project root:

```powershell
# Bump patch version (1.0.0+1 → 1.0.1+2)
.\scripts\bump_version.ps1

# Bump minor version (1.0.0+1 → 1.1.0+2)
.\scripts\bump_version.ps1 -minor

# Bump major version (1.0.0+1 → 2.0.0+2)
.\scripts\bump_version.ps1 -major

# Bump build number only (1.0.0+1 → 1.0.0+2)
.\scripts\bump_version.ps1 -build
```

### Manual Version Update

Edit `pubspec.yaml` directly:

```yaml
version: 1.2.3+5
```

### Command-Line Override

You can override the version during build:

```bash
# Override version name and build number
flutter build apk --build-name=1.5.0 --build-number=10

# For release builds
flutter build apk --release --build-name=2.0.0 --build-number=20
```

## Best Practices

### When to Bump Version

| Change Type      | Example              | Version Bump                  |
| :--------------- | :------------------- | :---------------------------- |
| Bug fixes        | Fixed crash on login | **PATCH** (1.0.0 → 1.0.1)     |
| New features     | Added dark mode      | **MINOR** (1.0.0 → 1.1.0)     |
| Breaking changes | Redesigned UI        | **MAJOR** (1.0.0 → 2.0.0)     |
| Internal testing | Daily build          | **BUILD** (1.0.0+1 → 1.0.0+2) |

### Release Workflow

1. **Before each release**, bump the appropriate version:
   ```powershell
   .\scripts\bump_version.ps1 -minor  # or -major, -patch
   ```

2. **Commit the change**:
   ```bash
   git add pubspec.yaml
   git commit -m "Bump version to 1.1.0"
   ```

3. **Build the release**:
   ```bash
   flutter build apk --release
   ```

4. **Tag the release** (optional but recommended):
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

## Advanced: Using Fastlane (Optional)

For production-grade automation, consider **Fastlane**:

```bash
# Install Fastlane
gem install fastlane

# Initialize in project
cd android  # or ios
fastlane init
```

Fastlane can automatically:

- Bump versions
- Build releases
- Upload to Play Store/App Store
- Manage certificates and provisioning

See [Fastlane Documentation](https://docs.fastlane.tools/) for setup details.

## Troubleshooting

### Script doesn't run

Ensure PowerShell execution policy allows scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Version not updating in app

After changing version, rebuild the app:

```bash
flutter clean
flutter build apk
```

---

**Need help?** Contact the development team or refer to the
[Flutter documentation](https://docs.flutter.dev/deployment/android#reviewing-the-app-manifest).
