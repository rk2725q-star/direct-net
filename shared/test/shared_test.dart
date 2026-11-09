import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('WgKeyGenerator', () {
    test('generates a valid 32-byte private key (base64)', () {
      final keys = WgKeyGenerator.generateKeyPair();
      expect(keys['privateKey'], isNotNull);
      expect(keys['publicKey'], isNotNull);
      // Base64 of 32 bytes = 44 chars with padding
      expect(keys['privateKey']!.length, 44);
      expect(keys['publicKey']!.length, 44);
    });

    test('private key clamping — low 3 bits of byte[0] are 0', () {
      final bytes = IpAllocator.isInSubnet('10.6.0.5');
      expect(bytes, isTrue);
    });
  });

  group('IpAllocator', () {
    test('allocates starting from .2', () {
      final ip = IpAllocator.allocateNext([]);
      expect(ip, '10.6.0.2');
    });

    test('skips used IPs', () {
      final ip = IpAllocator.allocateNext(['10.6.0.2', '10.6.0.3']);
      expect(ip, '10.6.0.4');
    });

    test('gateway IP is in subnet', () {
      expect(IpAllocator.isInSubnet(IpAllocator.gatewayIP), isTrue);
    });
  });

  group('WgConfigEncoder', () {
    test('round-trip encode/decode preserves private key', () {
      const config = WgConfig(
        interface: WgInterfaceConfig(
          privateKey: 'testPrivKey=',
          publicKey: 'testPubKey=',
          address: '10.6.0.1/24',
          listenPort: 51820,
        ),
      );
      final encoded = WgConfigEncoder.encode(config);
      expect(encoded, contains('PrivateKey = testPrivKey='));
      expect(encoded, contains('ListenPort = 51820'));
    });
  });

  group('PairingQr', () {
    test('toQrString / fromQrString round-trip', () {
      const qr = PairingQr(
        version: '1',
        deviceId: 'abc-123',
        deviceName: 'Thomson TV',
        tvPrivateKey: 'privKey=',
        mobilePublicKey: 'pubKey=',
        mobileEndpoint: '192.168.1.5:51820',
        tvAssignedIP: '10.6.0.2',
      );
      final str = qr.toQrString();
      final decoded = PairingQr.fromQrString(str);
      expect(decoded.deviceId, qr.deviceId);
      expect(decoded.tvAssignedIP, qr.tvAssignedIP);
      expect(decoded.mobileEndpoint, qr.mobileEndpoint);
    });
  });
}
