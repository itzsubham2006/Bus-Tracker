# College Bus Tracker — Flutter App

A live bus tracking app for college students. Shows real-time bus locations on a map using OpenStreetMap. No login required for students — just open the app and see where the buses are.

## Prerequisites

1. **Flutter SDK** (3.0+): [Install Flutter](https://docs.flutter.dev/get-started/install/windows/mobile)
2. **Android SDK**: Comes with Android Studio, or install standalone
3. After installing Flutter, run: `flutter doctor` and fix any issues

## Setup

### 1. Configure the Backend URL

Edit [`lib/config.dart`](lib/config.dart) — this is the **single place** to set the backend URL:

```dart
class AppConfig {
  // For Android emulator → host machine's localhost:
  static const String baseUrl = 'http://10.0.2.2:3000';

  // For physical device testing (use your computer's local IP):
  // static const String baseUrl = 'http://192.168.1.100:3000';

  // For production:
  // static const String baseUrl = 'https://your-server.railway.app';
}
```

### 2. Install Dependencies

```bash
cd app
flutter pub get
```

### 3. Run the App

```bash
# Make sure the backend is running first!
# In another terminal: cd backend && npm start

# Run on connected device or emulator:
flutter run
```

### 4. Build Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Share the APK via QR code, WhatsApp, etc. — no Play Store needed.

---

## How the App Works

### Student View (Default)
- Opens directly to a full-screen map with bus markers
- Bottom panel shows all 4 buses and their status
- Live updates arrive via Server-Sent Events (SSE) — no need to refresh
- If connection drops, a "Reconnecting..." banner appears at the top

### Hidden Driver Mode

> **Secret entry point**: **Long-press (hold for 2+ seconds) on the "College Bus Tracker" title text** in the app bar.

This opens the driver login screen where you enter the bus's secret token (printed to console when the backend first starts).

After entering the token once, it's saved securely on the device — you won't need to enter it again.

**Driver controls:**
- **Start Trip**: Requests location permission, starts sending GPS every 7 seconds
- **End Trip**: Stops sending GPS, marks bus as inactive for students

**Logging out of driver mode**: Tap the ⋮ menu in the top-right corner of the driver screen → "Log out of driver mode". This clears the saved token.

---

## Project Structure

```
app/
├── pubspec.yaml                    # Dependencies and app metadata
├── lib/
│   ├── main.dart                   # App entry point + Provider setup
│   ├── config.dart                 # Backend URL (single source of truth)
│   ├── models/
│   │   └── bus.dart                # Bus data model with JSON parsing
│   ├── services/
│   │   ├── api_service.dart        # HTTP calls to the backend
│   │   ├── sse_service.dart        # SSE streaming for live updates
│   │   └── location_service.dart   # GPS permission helpers
│   ├── providers/
│   │   ├── bus_provider.dart       # State: bus list + SSE connection
│   │   └── driver_provider.dart    # State: driver auth + location sending
│   ├── screens/
│   │   ├── home_screen.dart        # Student view (map + bottom panel)
│   │   ├── driver_login_screen.dart # Token entry screen
│   │   └── driver_screen.dart      # Start/End Trip controls
│   └── widgets/
│       ├── bus_map.dart            # FlutterMap with bus markers
│       ├── bus_marker.dart         # Individual bus marker on map
│       └── bus_list_panel.dart     # Draggable bottom sheet
└── android/                        # Android build configuration
```

---

## Key Technical Notes

- **Map**: Uses `flutter_map` + OpenStreetMap tiles (free, no API key needed)
- **State Management**: Provider (ChangeNotifier pattern)
- **SSE**: Custom implementation using `dart:io HttpClient` — works on Android/iOS (no browser-only APIs)
- **Token Storage**: `flutter_secure_storage` (Android Keystore encryption)
- **GPS**: `geolocator` package with periodic Timer (every 7 seconds)
- **No background service** in this version — the driver needs to keep the app open during trips

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Map shows blank tiles | Check internet connection; OSM tiles need network access |
| "Reconnecting..." banner won't go away | Make sure the backend is running and the URL in `config.dart` is correct |
| Location permission denied | Go to Android Settings → Apps → College Bus Tracker → Permissions → Location |
| Emulator: can't connect to backend | Use `10.0.2.2:3000` (not `localhost`) — `10.0.2.2` is the emulator's alias for the host machine |
| Physical device: can't connect | Use your computer's actual local IP (e.g., `192.168.1.100`), not `localhost`. Both devices must be on the same WiFi network |
