# BOAT Mobile Application Context & Architecture Specification (Flutter + Native Android Background Bridge)

> **Document Version:** 1.0.0  
> **Target Project:** BOAT (Bicycle Ownership and Address Tag) — Dedicated Flutter Mobile Application  
> **Audience:** AI Coding Agent / Autonomous Developer building the Flutter mobile app in a separate repository.

---

## 1. Executive Summary & Objective

**BOAT (Bicycle Ownership and Address Tag)** is a smart campus bicycle management and decentralized tracking ecosystem developed for closed university campuses (e.g. IIT Roorkee).

The system solves two distinct problems:
1. **Ownership (Physical Tap)**: Anyone who finds a parked, misplaced, or locked bicycle can tap its physical NFC tag with an unlocked phone (no special app required for public visitors) to view the owner's contact info (phone, hostel, room) and report a 1-tap GPS fix.
2. **Address & Passive Tracking (Decentralized Mesh)**: The bicycle's onboard low-power ESP32-C3 microcontroller acts as an Apple-standard **iBeacon**, broadcasting a unique ID in pulses (~100 ms pulse every 2.5 seconds, running for months on a 2000 mAh battery). **Any community member's smartphone running the BOAT app quietly detects this BLE signal in the background (5–50 meter radius), tags it with the phone's current GPS fix, and uploads it to the central TiDB database.** The owner can open their app at any time to view their bike's real-time position and historical breadcrumb trail on a campus map.

---

## 2. Core Architecture: Flutter + Native Android Background Bridge

### Why Pure Dart is Insufficient
In Flutter, when the user closes the app or locks their device, Android's operating system halts the Dart VM isolate. Background tasks created purely in Dart (`WorkManager` or Dart timer loops) cannot sustain real-time, low-latency BLE packet detection without being killed by the Android OS battery optimizer.

### The Hybrid Solution
- **User Interface & Client State**: **100% Flutter (Dart)**. Handles user authentication, interactive campus maps (Leaflet / OpenStreetMap), bike registration, status toggles (Active vs. Missing), NFC scanner, and profile settings.
- **Background Scanning Engine**: **Lightweight Native Android Background Service (`android-beacon-library`)**. Runs as a sticky Android Foreground/Background service with a silent notification. When an ESP32 beacon packet is received, the native Android service captures the phone's GPS location via `FusedLocationProviderClient` and fires an HTTP POST directly to the Next.js backend.
- **Communication Bridge**: `MethodChannel` (`com.boat.tracker/beacon_scanner`) allowing the Flutter UI to start, stop, configure, and inspect the status of the native background service.

```
┌────────────────────────────────────────────────────────────────────────┐
│                          SMARTPHONE                                    │
│                                                                        │
│   ┌───────────────────────────┐      ┌─────────────────────────────┐   │
│   │    Flutter UI (Dart)      │      │ Native Android Service      │   │
│   │                           │      │ (android-beacon-library)    │   │
│   │ • Auth & User Dashboard   │      │                             │   │
│   │ • Interactive Campus Map  │◄────►│ • BLE Beacon Listener       │   │
│   │ • Historical Trail View   │Method│ • 5-Minute In-Memory Cache  │   │
│   │ • Bike Registration & NFC │Chnnl │ • FusedLocation GPS Fix     │   │
│   └─────────────┬─────────────┘      └──────────────┬──────────────┘   │
└─────────────────┼───────────────────────────────────┼──────────────────┘
                  │                                   │
                  ▼                                   ▼
          Standard REST API                   HTTP POST Location Fix
    (GET /api/bikes, PATCH status)             (POST /api/location)
                  │                                   │
                  └─────────────────┬─────────────────┘
                                    ▼
                         ┌───────────────────────┐
                         │   Next.js API Server  │
                         │   (TiDB SQL Backend)  │
                         └───────────────────────┘
```

---

## 3. Critical Design Rules & Specifications

### Rule A: Client-Side Cooldown (Mobile Battery & Server Optimization)
To prevent battery drain and server spam when a user is stationary near a bicycle stand (e.g. sitting in a lecture hall or library with 50 bikes outside), the native Android beacon listener **must maintain an in-memory timestamp cache per tag/beacon ID**:
- **Cooldown Window**: `5 minutes (300,000 ms)`.
- When a beacon (`beaconUuid` + `beaconMajor` + `beaconMinor`) is sighted:
  - Check `lastReportedTime` in memory.
  - If `currentTime - lastReportedTime < 5 minutes`, **ignore the packet silently**.
  - If `> 5 minutes` (or first sighting): acquire GPS coordinates, dispatch the HTTP POST to `/api/location`, and update the timestamp.

### Rule B: Direct Database Ingestion (Zero Distance Pre-Queries)
The backend does not run expensive spatial distance queries before saving. Every incoming ping from the mobile app is written directly to the `location_reports` table in TiDB. The owner's map screen displays the latest position by querying:
```sql
SELECT lat, lng, recorded_at, source, reporter_note
FROM location_reports
WHERE bike_id = ?
ORDER BY recorded_at DESC LIMIT 1;
```

### Rule C: Idempotency & Single Active Missing Report Rule
When a bike is marked as **missing**, the database strictly enforces that only **one active missing report** exists per bicycle at any given time.
- Marking as missing when already marked missing returns HTTP `409 Conflict`.
- Marking as active (found) sets all active missing reports to `status = 'resolved'` and `resolved_at = CURRENT_TIMESTAMP`.

---

## 4. Hardware BLE Beacon Specifications

The onboard ESP32-C3 firmware transmits Apple-standard iBeacon advertisement packets using **non-connectable, unidirectional advertising** (`ADV_TYPE_NONCONN_IND`). It never connects to phones and never waits for acknowledgements.

### BLE iBeacon Packet Structure
- **Company Identifier**: `0x004C` (Apple Inc.)
- **Beacon Type**: `0x02 0x15` (Standard Proximity iBeacon)
- **Campus Proximity UUID**: `f7826da6-4fa2-4e98-8024-bc5b71e0893e` (32 hex characters / 16 bytes)
- **Major**: `1` (uint16 big-endian, represents campus cluster or zone)
- **Minor**: Bicycle-specific integer (`1`, `2`, `3`... uint16 big-endian assigned upon registration)
- **Measured Power (TxPower)**: `0xC5` (-59 dBm at 1 meter)
- **Duty Cycle**: ~100 ms broadcast burst, then 2.5 seconds deep sleep.

### AltBeacon Parser Layout String
```text
m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24
```

---

## 5. Backend Server & Database Specifications

### Active Secrets & Environment Configuration
```env
# Backend Database (TiDB Cloud Serverless)
DATABASE_URL=mysql://32PdWPMcGnu68aK.root:nJKzl3nLCDjmIQiD@gateway01.ap-southeast-1.prod.aws.tidbcloud.com:4000/boat?ssl={"rejectUnauthorized":true}

# JWT Secret for Session Generation & Bearer Tokens
JWT_SECRET=8f3c1a9e2b74d0c56e18a4f7b92d35c01e6a88f4b27c9d15e03a76b4c8f12d90

# Campus Metadata
NEXT_PUBLIC_CAMPUS_NAME=IIT Roorkee
NEXT_PUBLIC_CAMPUS_LAT=29.8649
NEXT_PUBLIC_CAMPUS_LNG=77.8966
NEXT_PUBLIC_BEACON_UUID=f7826da6-4fa2-4e98-8024-bc5b71e0893e

# Backend Server Endpoints
# Local Development (Phone must be on same Wi-Fi as PC):
DEV_SERVER_URL=http://YOUR_LOCAL_IP:3000
# Production / Tunnel:
PROD_SERVER_URL=https://your-deployed-boat-domain.com
```

### Database Schema Reference (TiDB / MySQL 8.0)
```sql
CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  phone VARCHAR(32) NULL,
  hostel VARCHAR(120) NULL,
  room VARCHAR(32) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
);

CREATE TABLE IF NOT EXISTS bikes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_id BIGINT UNSIGNED NOT NULL,
  public_id VARCHAR(16) NOT NULL,
  name VARCHAR(120) NOT NULL,
  color VARCHAR(64) NULL,
  model VARCHAR(120) NULL,
  tag_id VARCHAR(64) NOT NULL,
  status ENUM('active', 'missing') NOT NULL DEFAULT 'active',
  beacon_uuid CHAR(36) NOT NULL,
  beacon_major INT UNSIGNED NOT NULL DEFAULT 1,
  beacon_minor INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bikes_public_id (public_id),
  UNIQUE KEY uq_bikes_beacon (beacon_uuid, beacon_major, beacon_minor),
  KEY idx_bikes_owner (owner_id),
  KEY idx_bikes_tag_id (tag_id),
  CONSTRAINT fk_bikes_owner FOREIGN KEY (owner_id) REFERENCES users (id)
);

CREATE TABLE IF NOT EXISTS missing_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bike_id BIGINT UNSIGNED NOT NULL,
  status ENUM('active', 'resolved') NOT NULL DEFAULT 'active',
  reported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP NULL,
  notes VARCHAR(255) NULL,
  PRIMARY KEY (id),
  KEY idx_missing_bike_status (bike_id, status),
  CONSTRAINT fk_missing_reports_bike FOREIGN KEY (bike_id) REFERENCES bikes (id)
);

CREATE TABLE IF NOT EXISTS location_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bike_id BIGINT UNSIGNED NOT NULL,
  lat DECIMAL(10, 7) NOT NULL,
  lng DECIMAL(10, 7) NOT NULL,
  accuracy_m FLOAT NULL,
  source ENUM('web', 'ble', 'rfid', 'manual') NOT NULL DEFAULT 'web',
  reporter_note VARCHAR(255) NULL,
  recorded_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_bike_recorded (bike_id, recorded_at DESC),
  CONSTRAINT fk_reports_bike FOREIGN KEY (bike_id) REFERENCES bikes (id)
);
```

---

## 6. Complete REST API Specifications

The Flutter app authenticates via standard HTTP headers:
- Header: `Authorization: Bearer <TOKEN>` (or `Cookie: boat_session=<TOKEN>`).
- Content-Type: `application/json`.

### 1. User Registration
`POST /api/auth/register`
- **Auth Required**: No
- **Request Body**:
  ```json
  {
    "email": "student@iitr.ac.in",
    "password": "strongPassword123",
    "displayName": "Aarav Sharma",
    "phone": "+91 9876543210",
    "hostel": "Rajendra Bhawan",
    "room": "B-214"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "ok": true,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "student@iitr.ac.in",
      "display_name": "Aarav Sharma",
      "phone": "+91 9876543210",
      "hostel": "Rajendra Bhawan",
      "room": "B-214"
    }
  }
  ```

### 2. User Login
`POST /api/auth/login`
- **Auth Required**: No
- **Request Body**:
  ```json
  {
    "email": "student@iitr.ac.in",
    "password": "strongPassword123"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "ok": true,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "student@iitr.ac.in",
      "display_name": "Aarav Sharma",
      "phone": "+91 9876543210",
      "hostel": "Rajendra Bhawan",
      "room": "B-214"
    }
  }
  ```

### 3. Get Current User Profile
`GET /api/auth/me`
- **Auth Required**: Yes (`Authorization: Bearer <TOKEN>`)
- **Response (200 OK)**:
  ```json
  {
    "user": {
      "id": 1,
      "email": "student@iitr.ac.in",
      "display_name": "Aarav Sharma",
      "phone": "+91 9876543210",
      "hostel": "Rajendra Bhawan",
      "room": "B-214"
    }
  }
  ```

### 4. List User's Registered Bicycles
`GET /api/bikes`
- **Auth Required**: Yes (`Authorization: Bearer <TOKEN>`)
- **Response (200 OK)**:
  ```json
  {
    "bikes": [
      {
        "id": 1,
        "owner_id": 1,
        "public_id": "ab3k9mpq",
        "name": "Rockrider 520",
        "color": "Matte Black",
        "model": "BTWIN",
        "tag_id": "TAG-AB3K9MPQ",
        "status": "active",
        "beacon_uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
        "beacon_major": 1,
        "beacon_minor": 1,
        "created_at": "2026-10-28T12:00:00.000Z"
      }
    ]
  }
  ```

### 5. Register a New Bicycle
`POST /api/bikes`
- **Auth Required**: Yes (`Authorization: Bearer <TOKEN>`)
- **Request Body**:
  ```json
  {
    "name": "Atlas Peak",
    "color": "Navy Blue",
    "model": "Atlas 2024"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "ok": true,
    "bike": {
      "id": 2,
      "publicId": "7xz4m9kp",
      "tagId": "TAG-7XZ4M9KP",
      "beaconUuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
      "beaconMajor": 1,
      "beaconMinor": 2
    }
  }
  ```

### 6. Get Single Bicycle Details, Latest Fix & Historical Trail
`GET /api/bikes/:id`
- **Auth Required**: Yes (`Authorization: Bearer <TOKEN>`)
- **Response (200 OK)**:
  ```json
  {
    "bike": {
      "id": 1,
      "owner_id": 1,
      "public_id": "ab3k9mpq",
      "name": "Rockrider 520",
      "color": "Matte Black",
      "model": "BTWIN",
      "tag_id": "TAG-AB3K9MPQ",
      "status": "active",
      "beacon_uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
      "beacon_major": 1,
      "beacon_minor": 1,
      "created_at": "2026-10-28T12:00:00.000Z"
    },
    "lastLocation": {
      "id": 142,
      "bike_id": 1,
      "lat": 29.8655,
      "lng": 77.8960,
      "accuracy_m": 8.4,
      "source": "ble",
      "reporter_note": "Community relay",
      "recorded_at": "2026-10-29T14:10:00.000Z"
    },
    "trail": [
      {
        "id": 140,
        "bike_id": 1,
        "lat": 29.8649,
        "lng": 77.8966,
        "source": "rfid",
        "reporter_note": "Main Gate Stand",
        "recorded_at": "2026-10-29T13:45:00.000Z"
      },
      {
        "id": 142,
        "bike_id": 1,
        "lat": 29.8655,
        "lng": 77.8960,
        "source": "ble",
        "reporter_note": "Community relay",
        "recorded_at": "2026-10-29T14:10:00.000Z"
      }
    ],
    "activeMissingReport": null
  }
  ```

### 7. Toggle Bicycle Status (Active vs. Missing)
`PATCH /api/bikes/:id`
- **Auth Required**: Yes (`Authorization: Bearer <TOKEN>`)
- **To Mark as Missing**:
  ```json
  {
    "status": "missing",
    "notes": "Left near Central Library stand at 5 PM, lock was cut."
  }
  ```
  *Response (200 OK)*:
  ```json
  {
    "ok": true,
    "status": "missing",
    "message": "Bicycle reported as missing successfully."
  }
  ```
  *(If already missing, returns 409 Conflict with `alreadyMissing: true`)*.

- **To Mark as Found (Active)**:
  ```json
  {
    "status": "active"
  }
  ```
  *Response (200 OK)*:
  ```json
  {
    "ok": true,
    "status": "active",
    "message": "Bicycle marked as found and active."
  }
  ```

### 8. Location Ingestion (Direct Sighting Upload)
`POST /api/location`
- **Auth Required**: **NO** (Open to all community mesh relayers and background services)
- **Supported Payload Formats**:
  1. **By iBeacon (Standard Community Background Fix)**:
     ```json
     {
       "beaconUuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
       "beaconMajor": 1,
       "beaconMinor": 1,
       "lat": 29.86512,
       "lng": 77.89645,
       "accuracyM": 5.0,
       "source": "ble",
       "note": "Community phone relay"
     }
     ```
  2. **By Physical RFID Tag / Sticker**:
     ```json
     {
       "tagId": "04:A1:B2:C3:D4:E5:F6",
       "lat": 29.86490,
       "lng": 77.89660,
       "source": "rfid",
       "scannerId": "ROORKEE-GATE-1"
     }
     ```
  3. **By Public ID (Web or Manual QR/NFC Scan)**:
     ```json
     {
       "publicId": "ab3k9mpq",
       "lat": 29.86550,
       "lng": 77.89600,
       "source": "manual",
       "note": "Owner manual report from app"
     }
     ```
- **Response (200 OK)**:
  ```json
  {
    "ok": true,
    "bikeId": 1,
    "location": {
      "lat": 29.86512,
      "lng": 77.89645,
      "source": "ble",
      "recordedAt": "2026-10-29T14:15:30.000Z"
    }
  }
  ```

### 9. Public Bicycle Lookup (By Public ID)
`GET /api/public/bikes/:publicId`
- **Auth Required**: No (Public landing endpoint for NFC taps)
- **Response (200 OK)**:
  ```json
  {
    "bike": {
      "publicId": "ab3k9mpq",
      "name": "Rockrider 520",
      "color": "Matte Black",
      "model": "BTWIN",
      "tagId": "TAG-AB3K9MPQ",
      "status": "active",
      "registeredAt": "2026-10-28T12:00:00.000Z",
      "owner": {
        "displayName": "Aarav Sharma",
        "phone": "+91 9876543210",
        "hostel": "Rajendra Bhawan",
        "room": "B-214",
        "email": "student@iitr.ac.in"
      },
      "lastLocation": {
        "lat": 29.8655,
        "lng": 77.8960,
        "accuracyM": 8.4,
        "source": "ble",
        "recordedAt": "2026-10-29T14:10:00.000Z"
      }
    }
  }
  ```

---

## 7. Recommended Flutter Project Structure

When creating the Flutter repository, adopt this clean, feature-driven architectural structure:

```text
boat_mobile/
├── android/
│   └── app/src/main/kotlin/com/boat/tracker/
│       ├── MainActivity.kt                  # MethodChannel bridge setup
│       ├── BeaconScanningService.kt         # Android foreground service
│       └── BoatApplication.kt              # AltBeacon initialization
├── assets/
│   ├── icons/
│   └── images/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_endpoints.dart          # Base URL and API paths
│   │   │   ├── campus_config.dart          # Roorkee coordinates, UUID
│   │   │   └── app_colors.dart             # Palette matching web app
│   │   ├── network/
│   │   │   ├── api_client.dart             # Dio instance with interceptors
│   │   │   └── auth_interceptor.dart       # Bearer token injector
│   │   ├── services/
│   │   │   ├── beacon_scanner_service.dart # MethodChannel wrapper
│   │   │   ├── location_service.dart       # Geolocator wrapper
│   │   │   ├── nfc_service.dart            # NFC tag reader/writer
│   │   │   └── storage_service.dart        # Secure storage for JWT
│   │   └── theme/
│   │       └── app_theme.dart              # Material 3 Theme configuration
│   ├── features/
│   │   ├── auth/
│   │   │   ├── models/user.dart
│   │   │   ├── providers/auth_provider.dart
│   │   │   └── screens/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── bikes/
│   │   │   ├── models/
│   │   │   │   ├── bike.dart
│   │   │   │   └── location_report.dart
│   │   │   ├── providers/bike_provider.dart
│   │   │   └── screens/
│   │   │       ├── bike_detail_screen.dart # Map view + historical trail
│   │   │       ├── bike_list_screen.dart   # Dashboard of registered bikes
│   │   │       └── register_bike_screen.dart
│   │   ├── map/
│   │   │   └── widgets/
│   │   │       ├── campus_map_widget.dart  # flutter_map (OpenStreetMap)
│   │   │       └── breadcrumb_trail.dart   # Polylines for historical path
│   │   └── scanner/
│   │       └── screens/
│   │           ├── nfc_scanner_screen.dart # Direct NFC plate reader
│   │           └── mesh_status_screen.dart # Background service diagnostics
│   └── main.dart
└── pubspec.yaml
```

---

## 8. Color Palette & Typography (Matching Web Design)

To maintain brand consistency with the Next.js web application, configure the Flutter theme with these exact color tokens:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF14261C);       // Dark primary text
  static const Color moss = Color(0xFF1F4D3A);      // Primary brand green
  static const Color leaf = Color(0xFF2F6B4F);      // Accent green
  static const Color sand = Color(0xFFF3EFE4);      // Background off-white
  static const Color clay = Color(0xFFC45C26);      // Missing status orange
  static const Color mist = Color(0xFFE7EFE8);      // Light green tint cards
  static const Color surface = Colors.white;
  static const Color border = Color(0x261F4D3A);     // moss with 15% opacity
}
```

---

## 9. Ready-to-Paste Code Boilerplates

### A. `pubspec.yaml`
```yaml
name: boat_mobile
description: "BOAT - Bicycle Ownership and Address Tag Campus Mesh Tracker"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management & DI
  provider: ^6.1.2

  # Networking & Auth Storage
  dio: ^5.4.3+1
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.3

  # Mapping (Free OpenStreetMap, No Google API Key required)
  flutter_map: ^6.1.0
  latlong2: ^0.9.0

  # Hardware: Location & NFC
  geolocator: ^11.0.0
  nfc_manager: ^3.3.0
  permission_handler: ^11.3.1

  # UI Enhancements
  intl: ^0.19.0
  flutter_svg: ^2.0.10+1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

---

### B. Native Android Background Beacon Scanner

#### 1. Android Dependencies (`android/app/build.gradle`)
Add the official Android Beacon Library and Google Play Services Location:
```groovy
dependencies {
    implementation 'org.altbeacon:android-beacon-library:2.20.1'
    implementation 'com.google.android.gms:play-services-location:21.2.0'
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
}
```

#### 2. Android Manifest (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions required for BLE background beacon scanning & GPS -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.NFC" />

    <application
        android:name=".BoatApplication"
        android:label="BOAT"
        android:icon="@mipmap/ic_launcher">

        <service
            android:name=".BeaconScanningService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="location|connectedDevice" />

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### 3. Native Background Service with 5-Minute Cache (`BeaconScanningService.kt`)
```kotlin
package com.boat.tracker

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.LocationServices
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.altbeacon.beacon.*
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

class BeaconScanningService : Service(), BeaconConsumer {
    private val TAG = "BOAT_BLE_SERVICE"
    private lateinit var beaconManager: BeaconManager
    private val httpClient = OkHttpClient()
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    // 5-Minute Client-Side Cooldown Cache: Key is "UUID:Major:Minor", Value is System timestamp (ms)
    private val cooldownCache = ConcurrentHashMap<String, Long>()
    private val COOLDOWN_MS = 5 * 60 * 1000L // 5 minutes

    companion object {
        var serverUrl = "https://your-domain.com/api/location"
        var targetUuid = "f7826da6-4fa2-4e98-8024-bc5b71e0893e"
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundNotification()

        beaconManager = BeaconManager.getInstanceForApplication(this)
        // Add Apple iBeacon Parser format
        beaconManager.beaconParsers.clear()
        beaconManager.beaconParsers.add(BeaconParser().setBeaconLayout("m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24"))

        beaconManager.bind(this)
    }

    private fun startForegroundNotification() {
        val channelId = "boat_mesh_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "BOAT Campus Mesh Scanner",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Passively detecting campus bicycle beacons in the background"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("BOAT Mesh Scanner Active")
            .setContentText("Passively relaying campus bicycle locations")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()

        startForeground(101, notification)
    }

    override fun onBeaconServiceConnect() {
        val region = Region("campus_region", Identifier.parse(targetUuid), null, null)

        beaconManager.addRangeNotifier { beacons, _ ->
            for (beacon in beacons) {
                val major = beacon.id2.toInt()
                val minor = beacon.id3.toInt()
                val beaconKey = "$targetUuid:$major:$minor"

                val now = System.currentTimeMillis()
                val lastSent = cooldownCache[beaconKey] ?: 0L

                // Enforce 5-minute cooldown per unique bicycle tag
                if (now - lastSent >= COOLDOWN_MS) {
                    cooldownCache[beaconKey] = now
                    Log.d(TAG, "New beacon sighting: Major=$major, Minor=$minor. Acquiring GPS...")
                    dispatchFix(major, minor)
                }
            }
        }

        beaconManager.startRangingBeacons(region)
    }

    private fun dispatchFix(major: Int, minor: Int) {
        val fusedClient = LocationServices.getFusedLocationProviderClient(this)
        try {
            fusedClient.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    val payload = JSONObject().apply {
                        put("beaconUuid", targetUuid)
                        put("beaconMajor", major)
                        put("beaconMinor", minor)
                        put("lat", location.latitude)
                        put("lng", location.longitude)
                        put("accuracyM", location.accuracy)
                        put("source", "ble")
                        put("note", "Community phone background scan")
                    }

                    val request = Request.Builder()
                        .url(serverUrl)
                        .post(payload.toString().toRequestBody(JSON_MEDIA_TYPE))
                        .build()

                    httpClient.newCall(request).enqueue(object : okhttp3.Callback {
                        override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                            Log.e(TAG, "Failed to send location report: ${e.message}")
                        }
                        override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                            Log.d(TAG, "Check-in successful! Code: ${response.code}")
                            response.close()
                        }
                    })
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission missing: ${e.message}")
        }
    }

    override fun onDestroy() {
        beaconManager.unbind(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

#### 4. MethodChannel in `MainActivity.kt`
```kotlin
package com.boat.tracker

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.boat.tracker/beacon_scanner"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScanning" -> {
                    val serverUrl = call.argument<String>("serverUrl") ?: BeaconScanningService.serverUrl
                    val beaconUuid = call.argument<String>("beaconUuid") ?: BeaconScanningService.targetUuid
                    BeaconScanningService.serverUrl = serverUrl
                    BeaconScanningService.targetUuid = beaconUuid

                    val intent = Intent(this, BeaconScanningService::class.java)
                    startService(intent)
                    result.success(true)
                }
                "stopScanning" -> {
                    val intent = Intent(this, BeaconScanningService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

---

### C. Dart MethodChannel Wrapper (`lib/core/services/beacon_scanner_service.dart`)
```dart
import 'package:flutter/services.dart';

class BeaconScannerService {
  static const MethodChannel _channel = MethodChannel('com.boat.tracker/beacon_scanner');

  /// Starts the sticky native Android Foreground Beacon Scanner.
  static Future<bool> startScanning({
    required String serverUrl,
    required String beaconUuid,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('startScanning', {
        'serverUrl': serverUrl,
        'beaconUuid': beaconUuid,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Failed to start beacon scanner: '${e.message}'.");
      return false;
    }
  }

  /// Stops the native background service.
  static Future<bool> stopScanning() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopScanning');
      return success ?? false;
    } on PlatformException catch (e) {
      print("Failed to stop beacon scanner: '${e.message}'.");
      return false;
    }
  }
}
```

---

### D. Dart API Service Layer (`lib/core/network/api_service.dart`)
```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // Auth: Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final token = res.data['token'];
    if (token != null) {
      await _storage.write(key: 'jwt_token', value: token);
    }
    return res.data;
  }

  // Auth: Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? hostel,
    String? room,
  }) async {
    final res = await _dio.post('/api/auth/register', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
      'displayName': displayName,
      'phone': phone,
      'hostel': hostel,
      'room': room,
    });
    final token = res.data['token'];
    if (token != null) {
      await _storage.write(key: 'jwt_token', value: token);
    }
    return res.data;
  }

  // Bikes: List
  Future<List<dynamic>> getBikes() async {
    final res = await _dio.get('/api/bikes');
    return res.data['bikes'] as List<dynamic>;
  }

  // Bikes: Get details, latest fix, and historical trail
  Future<Map<String, dynamic>> getBikeDetail(int id) async {
    final res = await _dio.get('/api/bikes/$id');
    return res.data;
  }

  // Bikes: Register new
  Future<Map<String, dynamic>> registerBike({
    required String name,
    String? color,
    String? model,
  }) async {
    final res = await _dio.post('/api/bikes', data: {
      'name': name,
      'color': color,
      'model': model,
    });
    return res.data;
  }

  // Bikes: Toggle Status (Missing vs Active)
  Future<Map<String, dynamic>> updateBikeStatus(int id, String status, {String? notes}) async {
    final res = await _dio.patch('/api/bikes/$id', data: {
      'status': status,
      if (notes != null) 'notes': notes,
    });
    return res.data;
  }

  // Location: Manual Report
  Future<Map<String, dynamic>> reportLocation({
    required String publicId,
    required double lat,
    required double lng,
    double? accuracyM,
    String? note,
  }) async {
    final res = await _dio.post('/api/location', data: {
      'publicId': publicId,
      'lat': lat,
      'lng': lng,
      'accuracyM': accuracyM,
      'source': 'manual',
      if (note != null) 'note': note,
    });
    return res.data;
  }
}
```

---

## 10. Development Steps for the Autonomous Agent

When you start implementing the Flutter project in your repository, execute in this order:

1. **Step 1 — Project Initialization**:
   - Run `flutter create --org com.boat.tracker boat_mobile`.
   - Update `pubspec.yaml` with the dependencies listed in Section 9A.
2. **Step 2 — Android Background Bridge**:
   - Implement `BeaconScanningService.kt` with the 5-minute cooldown and `FusedLocationProviderClient`.
   - Configure `MainActivity.kt` with the `MethodChannel`.
   - Add permissions and service entry in `AndroidManifest.xml`.
3. **Step 3 — Networking & Authentication**:
   - Implement `api_service.dart` with token persistence in `flutter_secure_storage`.
   - Build `LoginScreen` and `RegisterScreen` styled with `AppColors`.
4. **Step 4 — Dashboard & Bike List**:
   - Fetch bikes via `GET /api/bikes`.
   - Render bike cards with status badges (`Active` / `Missing`), tags, and BLE minor IDs.
   - Add a toggle switch on the home screen to start/stop the passive community mesh scanner.
5. **Step 5 — Interactive Map & Historical Trail**:
   - Use `flutter_map` with `TileLayer` (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
   - Draw `MarkerLayer` for the latest sighting (colored red if Missing, green if Active, orange if Mock).
   - Draw `PolylineLayer` using coordinates from `trail` to visualize the historical breadcrumb path.
6. **Step 6 — Missing Status Toggle & Modal**:
   - Implement "Report Missing" button with a dialog for optional notes (`PATCH /api/bikes/:id` with `status: "missing"`).
   - Implement "Mark as Found" button (`status: "active"`).
7. **Step 7 — NFC Tag Scanner**:
   - Use `nfc_manager` to scan any NTAG215 plate, extract `/bike/<publicId>`, fetch public details, and present a 1-tap "Report GPS Fix" button.
