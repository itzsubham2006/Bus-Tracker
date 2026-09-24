#  College Bus Live Tracker

A complete real-time college bus tracking solution built with **Flutter** (Mobile App) and **Node.js / Express** (Live SSE Backend).

---

##  Highlights

- **Zero Friction for Students**: No signups, no logins, no personal location sharing. Students simply open the app to see live bus locations on an interactive OpenStreetMap.
- **Privacy-First Driver Mode**: Hidden behind a secret long-press gesture on the app bar. Unlocked using a per-bus secret token (no driver accounts).
- **Real-Time Streaming**: Server-Sent Events (SSE) push live bus coordinates instantly with zero polling overhead.
- **Signal Loss Detection**: If a bus loses GPS signal for >45 seconds, the app highlights it as stale/signal lost.
- **Offline & Free Map Tiles**: Built with `flutter_map` and OpenStreetMap — 100% free with no Google Maps API keys required.

---

##  Architecture

```
college-bus-tracker/
├── app/                       # Flutter Mobile Application (Android / iOS)
│   ├── lib/
│   │   ├── main.dart          # Entry point & Provider tree
│   │   ├── config.dart        # Backend URL configuration
│   │   ├── models/            # Bus data model & JSON serialization
│   │   ├── services/          # SSE service, API client, Geolocator
│   │   ├── providers/         # BusProvider (state) & DriverProvider (auth/GPS)
│   │   ├── screens/           # Student map view, Driver login, Driver dashboard
│   │   └── widgets/           # Map, custom bus markers, draggable status sheet
│   └── android/               # Android native configuration & launcher icons
│
└── backend/                   # Node.js + Express Real-time Server
    ├── src/
    │   ├── server.js          # Express app entry point
    │   ├── db.js              # SQLite persistent store & token management
    │   ├── state.js           # Live in-memory bus state & SSE broadcasting
    │   ├── routes/            # Buses, Driver, and Admin routes
    │   └── middleware/        # Request logger, error handlers, rate limiting
    ├── package.json
    └── .env.example
```

---

##  Quick Start

### 1. Backend Server Setup

```bash
cd backend
npm install
npm start
```
The server will run at `http://localhost:3000`. On first launch, it initializes `buses.db` (SQLite) and outputs 4 secret driver tokens.

### 2. Mobile App (Flutter)

```bash
cd app
flutter pub get
flutter run
```

To configure the backend IP for physical devices or production:
Edit `app/lib/config.dart`:
```dart
class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:3000'; // Android emulator
  // static const String baseUrl = 'http://192.168.1.X:3000'; // Physical device on LAN
  // static const String baseUrl = 'https://your-server.railway.app'; // Production
}
```

### 3. Build Android APK

```bash
cd app
flutter build apk --debug
```
*Compiled APK output will be located in `app/build/app/outputs/flutter-apk/app-debug.apk`.*

---

##  Driver Mode & Authentication

1. **How to Enter Driver Mode**:  
   On the main screen, **long-press (press and hold for 2+ seconds)** the title **"College Bus Tracker"** in the top navigation bar.
2. **Authentication**:  
   Enter the secret 64-character token assigned to your bus. The token is verified against the backend and securely stored in device keystore (`flutter_secure_storage`).
3. **Trip Controls**:  
   Tap **"Start Trip"** to begin broadcasting GPS coordinates every 7 seconds. Tap **"End Trip"** to mark the bus as inactive and clear its live coordinates from student maps.

---

##  API Overview

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| `GET` | `/health` | Server health check | Public |
| `GET` | `/api/buses` | Fetch all bus statuses | Public |
| `GET` | `/api/stream` | Server-Sent Events (SSE) live updates | Public |
| `POST` | `/api/driver/verify` | Verify driver token | Token in Body |
| `POST` | `/api/bus/:id/location` | Post GPS update (rate-limited 1/3s) | Token in Body |
| `POST` | `/api/bus/:id/toggle` | Activate / Deactivate bus trip | Token in Body |
| `POST` | `/api/admin/regenerate-token`| Regenerate token for a bus | Admin Secret |

---

##  License

MIT License. See [LICENSE](LICENSE) for details.
