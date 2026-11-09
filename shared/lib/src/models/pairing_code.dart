import 'dart:convert';
import 'dart:math';
import 'package:equatable/equatable.dart';

/// Represents a 6-digit code-based pairing payload for DirectNet.
/// Eliminates the need for TV cameras / QR scanners.
class PairingCode extends Equatable {
  final String code; // 6-digit numeric string, e.g. "849215"
  final String gatewayIp; // e.g. "192.168.43.1"
  final int gatewayPort; // default: 10808
  final String deviceName; // e.g. "Samsung S24" or "DirectNet Phone"
  final DateTime createdAt;

  const PairingCode({
    required this.code,
    required this.gatewayIp,
    this.gatewayPort = 10808,
    required this.deviceName,
    required this.createdAt,
  });

  /// Format code into two 3-digit blocks (e.g. "849 215") for 10-foot readability
  String get formattedCode {
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  /// Generate a random 6-digit pairing code
  static String generateRandomCode() {
    final rng = Random();
    final number = 100000 + rng.nextInt(900000); // 100000..999999
    return number.toString();
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'ip': gatewayIp,
        'port': gatewayPort,
        'name': deviceName,
        'created': createdAt.toIso8601String(),
      };

  factory PairingCode.fromJson(Map<String, dynamic> json) => PairingCode(
        code: json['code'] as String,
        gatewayIp: json['ip'] as String,
        gatewayPort: json['port'] as int? ?? 10808,
        deviceName: json['name'] as String? ?? 'Phone Gateway',
        createdAt: json['created'] != null
            ? DateTime.parse(json['created'] as String)
            : DateTime.now(),
      );

  /// Compact JSON for UDP discovery beacon
  String toBeaconJson() => jsonEncode({
        'app': 'directnet',
        'code': code,
        'ip': gatewayIp,
        'port': gatewayPort,
        'name': deviceName,
      });

  static PairingCode? fromBeaconJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['app'] != 'directnet') return null;
      return PairingCode(
        code: json['code'].toString(),
        gatewayIp: json['ip'] as String,
        gatewayPort: json['port'] as int? ?? 10808,
        deviceName: json['name'] as String? ?? 'Phone Gateway',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [code, gatewayIp, gatewayPort, deviceName];
}

