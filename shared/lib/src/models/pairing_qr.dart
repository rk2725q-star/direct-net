import 'dart:convert';
import 'wg_config.dart';

/// Data embedded in the QR code for pairing TV to mobile gateway
class PairingQr {
  final String version;        // "1" — for forward compatibility
  final String deviceId;       // UUID assigned to this TV
  final String deviceName;     // e.g. "Thomson TV"

  /// TV's WireGuard private key (generated on mobile, sent to TV via QR)
  final String tvPrivateKey;

  /// Mobile's WireGuard public key (TV needs this to authenticate the server)
  final String mobilePublicKey;

  /// Mobile's WireGuard endpoint: ip:port for the TV to connect to
  /// Uses mDNS / local IP resolved at QR generation time
  final String mobileEndpoint;

  /// IP assigned to this TV inside the VPN subnet
  final String tvAssignedIP;

  /// Allowed IPs through the tunnel (0.0.0.0/0 = all traffic = full internet sharing)
  final String allowedIPs;

  final List<String> dns;

  const PairingQr({
    required this.version,
    required this.deviceId,
    required this.deviceName,
    required this.tvPrivateKey,
    required this.mobilePublicKey,
    required this.mobileEndpoint,
    required this.tvAssignedIP,
    this.allowedIPs = '0.0.0.0/0, ::/0',
    this.dns = const ['1.1.1.1', '8.8.8.8'],
  });

  /// Encode to compact JSON string for QR embedding
  String toQrString() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  static PairingQr fromQrString(String qrStr) {
    final json = jsonDecode(utf8.decode(base64Url.decode(qrStr))) as Map<String, dynamic>;
    return PairingQr.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'id': deviceId,
    'name': deviceName,
    'tvPk': tvPrivateKey,
    'mobPub': mobilePublicKey,
    'ep': mobileEndpoint,
    'ip': tvAssignedIP,
    'aip': allowedIPs,
    'dns': dns,
  };

  factory PairingQr.fromJson(Map<String, dynamic> json) => PairingQr(
    version: json['v'] as String,
    deviceId: json['id'] as String,
    deviceName: json['name'] as String,
    tvPrivateKey: json['tvPk'] as String,
    mobilePublicKey: json['mobPub'] as String,
    mobileEndpoint: json['ep'] as String,
    tvAssignedIP: json['ip'] as String,
    allowedIPs: json['aip'] as String? ?? '0.0.0.0/0, ::/0',
    dns: List<String>.from(json['dns'] as List? ?? ['1.1.1.1', '8.8.8.8']),
  );

  /// Convert to a WireGuard client config (for the TV)
  WgConfig toTvWgConfig() => WgConfig(
    interface: WgInterfaceConfig(
      privateKey: tvPrivateKey,
      publicKey: '', // TV derives this from private key
      address: '$tvAssignedIP/32',
      listenPort: 0, // TV is client, no listen port needed
      dns: dns,
    ),
    peers: [
      WgPeerConfig(
        publicKey: mobilePublicKey,
        allowedIPs: allowedIPs,
        endpoint: mobileEndpoint,
        persistentKeepalive: 25,
      ),
    ],
  );
}

