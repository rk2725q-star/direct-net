import '../models/wg_config.dart';

/// Encodes/decodes WireGuard config in the standard .conf file format
class WgConfigEncoder {
  /// Encode a WgConfig to WireGuard .conf format string
  static String encode(WgConfig config) {
    final buf = StringBuffer();

    // [Interface] section
    buf.writeln('[Interface]');
    buf.writeln('PrivateKey = ${config.interface.privateKey}');
    buf.writeln('Address = ${config.interface.address}');
    if (config.interface.listenPort > 0) {
      buf.writeln('ListenPort = ${config.interface.listenPort}');
    }
    if (config.interface.dns.isNotEmpty) {
      buf.writeln('DNS = ${config.interface.dns.join(', ')}');
    }
    // PostUp/PostDown for IP forwarding (server side only — added externally)

    // [Peer] sections
    for (final peer in config.peers) {
      buf.writeln();
      buf.writeln('[Peer]');
      buf.writeln('PublicKey = ${peer.publicKey}');
      buf.writeln('AllowedIPs = ${peer.allowedIPs}');
      if (peer.endpoint != null) {
        buf.writeln('Endpoint = ${peer.endpoint}');
      }
      if (peer.persistentKeepalive != null) {
        buf.writeln('PersistentKeepalive = ${peer.persistentKeepalive}');
      }
    }

    return buf.toString();
  }

  /// Parse a WireGuard .conf format string back to WgConfig
  static WgConfig decode(String confStr, {String publicKey = ''}) {
    String privKey = '';
    String address = '';
    int listenPort = 0;
    List<String> dns = [];
    List<WgPeerConfig> peers = [];

    String? currentPeerPub;
    String? currentPeerAllowedIPs;
    String? currentPeerEndpoint;
    int? currentPeerKeepalive;
    bool inPeer = false;

    void flushPeer() {
      if (currentPeerPub != null) {
        peers.add(WgPeerConfig(
          publicKey: currentPeerPub!,
          allowedIPs: currentPeerAllowedIPs ?? '0.0.0.0/0',
          endpoint: currentPeerEndpoint,
          persistentKeepalive: currentPeerKeepalive,
        ));
        currentPeerPub = null;
        currentPeerAllowedIPs = null;
        currentPeerEndpoint = null;
        currentPeerKeepalive = null;
      }
    }

    for (final rawLine in confStr.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line == '[Interface]') {
        inPeer = false;
        flushPeer();
        continue;
      }
      if (line == '[Peer]') {
        inPeer = true;
        flushPeer();
        continue;
      }

      final parts = line.split('=');
      if (parts.length < 2) continue;
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();

      if (!inPeer) {
        switch (key) {
          case 'PrivateKey': privKey = value;
          case 'Address': address = value;
          case 'ListenPort': listenPort = int.tryParse(value) ?? 0;
          case 'DNS': dns = value.split(',').map((s) => s.trim()).toList();
        }
      } else {
        switch (key) {
          case 'PublicKey': currentPeerPub = value;
          case 'AllowedIPs': currentPeerAllowedIPs = value;
          case 'Endpoint': currentPeerEndpoint = value;
          case 'PersistentKeepalive': currentPeerKeepalive = int.tryParse(value);
        }
      }
    }
    flushPeer();

    return WgConfig(
      interface: WgInterfaceConfig(
        privateKey: privKey,
        publicKey: publicKey,
        address: address,
        listenPort: listenPort,
        dns: dns,
      ),
      peers: peers,
    );
  }
}

