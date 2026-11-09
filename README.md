# DirectNet

> **Share your mobile internet to your TV — no hotspot needed.**
> A WireGuard-based secure gateway that pairs your Android phone and Thomson Android TV 9 with one QR code scan.

---

## How it Works

```
📱 Your Phone (Mobile Data)
        │
        │  WireGuard Tunnel (encrypted, auto-reconnect)
        │  port 51820 / UDP
        │
📺 Thomson Android TV 9
```

No hotspot. No carrier restrictions. Zero-battery-drain idle. Pairs once, connects forever.

---

## Project Structure

```
directnet/
├── shared/           # Dart package — WG models, key gen, QR encoding
├── mobile_app/       # Phone app — WireGuard gateway + dashboard
└── tv_app/           # Android TV app — WireGuard client + TV UI
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.41.2+ |
| Android SDK | API 26+ (Android 8+) |
| Android NDK | r25c (for WireGuard native libs) |

---

## Build & Run

### 1. Mobile App (Phone)

```bash
cd mobile_app
flutter pub get
flutter run   # with phone connected via USB
```

**OR build APK:**
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Install on phone: `adb install build/app/outputs/flutter-apk/app-release.apk`

---

### 2. TV App (Thomson Android TV 9)

```bash
cd tv_app
flutter pub get
flutter build apk --release
```

**Install on TV via ADB over WiFi:**
```bash
# On TV: Settings → About → Developer Options → Enable ADB over network
# Note your TV's IP address (Settings → Network)
adb connect <TV_IP>:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Or sideload via USB:**
```bash
adb -s <device_id> install tv_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## First-time Setup

1. **Phone**: Open DirectNet → tap **"Initialize Gateway"**
2. **Phone**: Tap **"+ Add TV"** → QR code appears
3. **TV**: Open DirectNet TV → select **"Scan QR Code to Pair"**
4. **TV**: Point camera at phone QR code
5. ✅ **Done!** TV is now connected through your phone's internet

From now on, the TV auto-connects every time it boots up.

---

## Android Permissions Required

### Mobile App
| Permission | Reason |
|-----------|--------|
| `BIND_VPN_SERVICE` | Create the WireGuard tunnel |
| `FOREGROUND_SERVICE` | Keep gateway alive in background |
| `INTERNET` | Route TV traffic through mobile data |
| `ACCESS_WIFI_STATE` | Get local IP for QR code endpoint |
| `WAKE_LOCK` | Prevent gateway from sleeping |

### TV App
| Permission | Reason |
|-----------|--------|
| `BIND_VPN_SERVICE` | Connect WireGuard VPN client |
| `RECEIVE_BOOT_COMPLETED` | Auto-connect on TV boot |
| `CAMERA` | Scan QR code during pairing |

> **No root required.** Both apps use Android's standard `VpnService` API.

---

## Network Details

| Setting | Value |
|---------|-------|
| VPN Subnet | `10.6.0.0/24` |
| Gateway (Phone) IP | `10.6.0.1` |
| TV IP | `10.6.0.2` (first TV) |
| WireGuard Port | `51820/UDP` |
| DNS | `1.1.1.1`, `8.8.8.8` |
| Encryption | ChaCha20-Poly1305 (WireGuard) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| TV can't find phone gateway | Make sure both are on same WiFi OR phone's local IP matches QR endpoint |
| VPN permission dialog on phone | Accept it — required for WireGuard |
| TV auto-connect not working | Check that `RECEIVE_BOOT_COMPLETED` permission is granted |
| QR scan not working (no camera on TV) | Use ADB to push config manually (see below) |

### Manual Config (if TV has no camera)
```bash
# On phone, copy the WG config string from DirectNet → Settings → Export
# On TV via ADB:
adb shell am start -n com.directnet.tv_app/.MainActivity --es "wg_config" "<base64_config>"
```

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3 + Dart |
| State management | Riverpod 2 |
| VPN tunnel | WireGuard (`wireguard_flutter 0.1.3`) |
| QR code | `qr_flutter` + `mobile_scanner` |
| Storage | `shared_preferences` |
| Charts | `fl_chart` |
| Fonts | Google Fonts (Outfit) |

---

## License

MIT © DirectNet 2026

