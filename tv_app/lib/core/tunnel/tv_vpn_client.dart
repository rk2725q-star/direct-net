import 'package:flutter/services.dart';

/// Dart client interface to Android TV's native VpnService.
/// Intercepts 100% of TV app traffic (YouTube, Netflix, Prime, Hotstar, Play Store)
/// and routes it through hev-socks5-tunnel to the phone gateway.
class TvVpnClient {
  static const _channel = MethodChannel('com.directnet.tv_app/vpn');

  /// Start the local TV VPN tunnel routing all apps to [host]:[port]
  static Future<bool> startVpn({
    required String host,
    required int port,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('startVpn', {
        'host': host,
        'port': port,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stop the VPN tunnel
  static Future<bool> stopVpn() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopVpn');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check whether the VPN tunnel is currently active
  static Future<bool> isVpnRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isVpnRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get the active Wi-Fi Gateway IP (the phone's IP from DHCP)
  static Future<String?> getWifiGatewayIp() async {
    try {
      final ip = await _channel.invokeMethod<String>('getWifiGatewayIp');
      return ip;
    } catch (_) {
      return null;
    }
  }
}
