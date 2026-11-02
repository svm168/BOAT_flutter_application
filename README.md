<div align="center">

# 🚲 BOAT Mobile
### Bicycle Ownership and Address Tag

[![Total Downloads](https://img.shields.io/github/downloads/svm168/BOAT_flutter_application/total.svg?label=Total%20Downloads&style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI0ZBRjZFRSI+PHBhdGggZD0iTTUgMjBoMTR2LTJINXYyek0xOSA5aC00VjNIOXY2SDVsNyA3IDctN3oiLz48L3N2Zz4=&color=1F4D3A&labelColor=243E31)](https://github.com/svm168/BOAT_flutter_application/releases)
[![Latest Release](https://img.shields.io/github/v/release/svm168/BOAT_flutter_application?style=for-the-badge&logo=github&color=2D6A4F&labelColor=243E31)](https://github.com/svm168/BOAT_flutter_application/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-2D6A4F?style=for-the-badge&logo=flutter&labelColor=243E31)](https://flutter.dev)

<p align="center">
  <b>Campus bicycle number plates with NFC ownership lookup, passive BLE mesh scanning, and shortest-path routing.</b>
</p>

[🌐 Web App Repository](https://github.com/svm168/boat) • [🖥️ Live Web Portal](https://boat-eight-lemon.vercel.app) • [🤖 Download Android APK](https://github.com/svm168/BOAT_flutter_application/releases/latest) • [🍎 Download iOS Package](https://github.com/svm168/BOAT_flutter_application/releases/latest) • [📦 All Releases & Versions](https://github.com/svm168/BOAT_flutter_application/releases)

</div>

---

### 📥 Downloads & Releases

| Platform | Package Format | Status | Download Link |
| :--- | :--- | :--- | :--- |
| **Android** | `.apk` (ARM64 / Universal) | Ready for direct sideload | [⬇️ **Download Android APK**](https://github.com/svm168/BOAT_flutter_application/releases/latest) |
| **iOS / iPadOS** | `.ipa` / TestFlight | Sideload via AltStore / Sideloadly | [⬇️ **Download iOS IPA**](https://github.com/svm168/BOAT_flutter_application/releases/latest) |
| **All Versions** | All Formats | Full build archive & changelogs | [📦 **Browse All Releases**](https://github.com/svm168/BOAT_flutter_application/releases) |

---

### ✨ Features
- **Community Mesh Scanner**: Background BLE iBeacon pulse detection with battery-efficient scanning and periodic GPS fix relaying.
- **Shortest Road Routing**: OpenStreetMap road-following navigation from your live device coordinates directly to the bicycle.
- **Proximity-Gated GPS Updates**: Prevent accidental false fixes by verifying BLE beacon proximity before saving a location.
- **NFC Tag Programming**: Write the public ownership plate link straight to NTAG215 stickers using your phone's NFC antenna.
- **Sightings Telemetry**: Live timeline showing recent sightings, detection sources, and coordinates.

---

### 🏗️ Mobile Architecture & Background Engine

The mobile application utilizes a hybrid Flutter and native platform bridge designed to maintain continuous BLE scanning without running down device battery:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MOBILE CLIENT SUBSYSTEM                         │
│                                                                        │
│   ┌───────────────────────────┐      ┌─────────────────────────────┐   │
│   │    Flutter UI Layer       │      │  Native Android/iOS Service │   │
│   │    (Dart / Provider)      │      │  (BeaconScanningService)    │   │
│   │ • Auth & User Dashboard   │◄────►│ • Background BLE Scanner    │   │
│   │ • Road Shortest Path Map  │Method│ • In-Memory Cooldown Cache  │   │
│   │ • Proximity Gating Logic  │Chnnl │ • FusedLocation GPS Provider│   │
│   │ • On-Device NFC Flasher   │      │ • REST Location Dispatcher  │   │
│   └───────────────────────────┘      └──────────────┬──────────────┘   │
└─────────────────────────────────────────────────────┼──────────────────┘
                                                      │
                                                      ▼
                                            POST /api/location
                                      (Cloud Mesh Ingestion Endpoint)
```

- **UI & Interaction Layer (Flutter/Dart)**:
  - Multi-platform interface managing authentication sessions, interactive maps, bicycle ownership details, and NFC read/write workflows.
  - Consumes live telemetry via an `EventChannel` to show real-time nearby BLE packets in the Mesh Diagnostics screen.

- **Native Background Service Bridge**:
  - `MethodChannel` (`com.boat.tracker/beacon_scanner`): Handles bidirectional control (start, stop, query status, toggle Bluetooth) between Flutter and the native OS.
  - Native Android Service (`BeaconScanningService.kt`): Runs as a foreground service with a persistent low-priority notification, preventing Android OS battery optimization from killing BLE discovery when the screen is locked.
  - In-Memory Cooldown Cache: Tracks recent sightings per hardware ID to prevent redundant GPS reports and conserve mobile bandwidth.

---

### 📁 Mobile Project Structure

```
lib/
├── core/
│   ├── constants/       # API routes, campus coordinates, and design tokens
│   ├── network/         # HTTP client with JWT interceptor and CORS headers
│   └── services/        # MethodChannel beacon scanner, NFC manager, and storage
├── features/
│   ├── auth/            # Sign in, registration, session persistence, and state
│   ├── bikes/           # Bicycle list, detail telemetry, status toggling, and forms
│   ├── map/             # Interactive campus map, pedestrian routing, and markers
│   └── scanner/         # Mesh diagnostics, nearby BLE radar, and NFC scanner
└── main.dart            # Application entrypoint and dependency providers
```

---

### 🚀 Getting Started for Developers

1. **Clone the repository**:
   ```bash
   git clone https://github.com/svm168/BOAT_flutter_application.git
   cd BOAT_flutter_application
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on connected device or Chrome**:
   ```bash
   flutter run -d chrome
   ```
