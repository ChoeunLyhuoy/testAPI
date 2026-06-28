# KOK POS — Flutter Mobile App

## Prerequisites
- Flutter SDK ≥ 3.5.0
- Dart SDK ≥ 3.5.0
- Android SDK (API 21+) for Android builds
- Xcode 15+ for iOS builds

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release

# Build iOS (macOS only)
flutter build ios --release
```

## APK Output
```
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

## API Configuration
Edit `lib/services/api_service.dart`:
```dart
static String get _host => '10.250.0.196';  // ← change to your server IP
```

## Screens
- Login
- Dashboard — stats banner, operations grid, setup grid
- Sale — product grid + cart + payment flow → POST /orders
- Purchase — PUR-xxx list + create order form
- Invoice — sold tab + daily report tab
- Stock / Inventory — warehouse filters + download
- Bank Account — CRUD with image upload
- Category — CRUD with image upload
- Supplier — CRUD with image upload  
- Product — grid with price badge, copy, delete
- Customer — CRUD list
- Report — dashboard stats
- Settings — logout
# testAPI
