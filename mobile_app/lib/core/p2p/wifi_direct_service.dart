import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiDirectGroupInfo {
  final String ssid;
  final String passphrase;
  final String ip;
  final int port;
  final bool isOwner;

  const WifiDirectGroupInfo({
    required this.ssid,
    required this.passphrase,
    this.ip = '192.168.49.1',
    this.port = 10808,
    this.isOwner = true,
  });

  factory WifiDirectGroupInfo.fromMap(Map<dynamic, dynamic> map) {
    return WifiDirectGroupInfo(
      ssid: (map['ssid'] as String?)?.isNotEmpty == true
          ? map['ssid'] as String
          : 'DIRECT-Net',
      passphrase: (map['passphrase'] as String?)?.isNotEmpty == true
          ? map['passphrase'] as String
          : '87654321',
      ip: (map['ip'] as String?) ?? '192.168.49.1',
      port: (map['port'] as int?) ?? 10808,
      isOwner: (map['isOwner'] as bool?) ?? true,
    );
  }
}

/// Service that manages Android's native Wi-Fi Direct (P2P / WifiP2pManager).
/// Creates an autonomous P2P group so TV can connect directly WITHOUT using
/// the phone's "Mobile Hotspot" toggle in Android settings.
class WifiDirectService {
  static const _channel = MethodChannel('com.directnet.mobile_app/wifi_p2p');

  /// Request runtime permissions required for Wi-Fi Direct
  static Future<bool> requestPermissions() async {
    try {
      // Nearby WiFi devices on Android 13+
      final nearbyStatus = await Permission.nearbyWifiDevices.request();
      if (nearbyStatus.isGranted) return true;

      // Location fallback for Android 12 and below
      final locStatus = await Permission.locationWhenInUse.request();
      return locStatus.isGranted || nearbyStatus.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Start an autonomous Wi-Fi Direct group (acts as a direct Wi-Fi SoftAP)
  /// Mobile Hotspot switch in Android Settings remains completely OFF!
  static Future<WifiDirectGroupInfo?> createGroup() async {
    try {
      await requestPermissions();
      final res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('createGroup');
      if (res != null) {
        return WifiDirectGroupInfo.fromMap(res);
      }
    } catch (_) {}
    return null;
  }

  /// Stop and tear down the Wi-Fi Direct group
  static Future<void> removeGroup() async {
    try {
      await _channel.invokeMethod('removeGroup');
    } catch (_) {}
  }

  /// Get current group information if already running
  static Future<WifiDirectGroupInfo?> getGroupInfo() async {
    try {
      final res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getGroupInfo');
      if (res != null) {
        return WifiDirectGroupInfo.fromMap(res);
      }
    } catch (_) {}
    return null;
  }
}

