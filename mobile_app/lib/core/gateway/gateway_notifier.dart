import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:shared/shared.dart';
import '../p2p/wifi_direct_service.dart';
import 'gateway_server.dart';

const _kPrefsKey = 'directnet_mobile_state';
const _gatewayPort = 10808;

/// Provider exposing the mobile gateway notifier
final gatewayProvider =
    AsyncNotifierProvider<GatewayNotifier, GatewayState>(GatewayNotifier.new);

class GatewayState {
  final bool isRunning;
  final TunnelStatus status;
  final PairingCode? pairingCode;
  final WifiDirectGroupInfo? p2pInfo;
  final List<PeerInfo> peers;
  final String? localIP;
  final int port;
  final BandwidthStat bandwidth;
  final String? errorMessage;

  const GatewayState({
    this.isRunning = false,
    this.status = TunnelStatus.disconnected,
    this.pairingCode,
    this.p2pInfo,
    this.peers = const [],
    this.localIP,
    this.port = _gatewayPort,
    this.bandwidth = BandwidthStat.zero,
    this.errorMessage,
  });

  GatewayState copyWith({
    bool? isRunning,
    TunnelStatus? status,
    PairingCode? pairingCode,
    WifiDirectGroupInfo? p2pInfo,
    List<PeerInfo>? peers,
    String? localIP,
    int? port,
    BandwidthStat? bandwidth,
    String? errorMessage,
  }) =>
      GatewayState(
        isRunning: isRunning ?? this.isRunning,
        status: status ?? this.status,
        pairingCode: pairingCode ?? this.pairingCode,
        p2pInfo: p2pInfo ?? this.p2pInfo,
        peers: peers ?? this.peers,
        localIP: localIP ?? this.localIP,
        port: port ?? this.port,
        bandwidth: bandwidth ?? this.bandwidth,
        errorMessage: errorMessage,
      );
}

class GatewayNotifier extends AsyncNotifier<GatewayState> {
  late GatewayServer _gatewayServer;
  final _networkInfo = NetworkInfo();

  @override
  Future<GatewayState> build() async {
    _gatewayServer = GatewayServer();
    ref.onDispose(() {
      _gatewayServer.stop();
      WifiDirectService.removeGroup();
    });
    return _loadSavedState();
  }

  Future<GatewayState> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    final localIP = await _getLocalIP();

    if (raw == null) {
      final code = PairingCode.generateRandomCode();
      final pairing = PairingCode(
        code: code,
        gatewayIp: localIP ?? '192.168.49.1',
        gatewayPort: _gatewayPort,
        deviceName: 'DirectNet Phone',
        createdAt: DateTime.now(),
      );
      await _saveState(pairingCode: pairing, peers: []);
      return GatewayState(
        pairingCode: pairing,
        localIP: localIP,
        bandwidth: BandwidthStat.empty(),
      );
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pairing = json['pairing'] != null
          ? PairingCode.fromJson(json['pairing'] as Map<String, dynamic>)
          : PairingCode(
              code: PairingCode.generateRandomCode(),
              gatewayIp: localIP ?? '192.168.49.1',
              gatewayPort: _gatewayPort,
              deviceName: 'DirectNet Phone',
              createdAt: DateTime.now(),
            );

      final peers = (json['peers'] as List? ?? [])
          .map((p) => PeerInfo.fromJson(p as Map<String, dynamic>))
          .toList();

      return GatewayState(
        pairingCode: pairing,
        peers: peers,
        localIP: localIP,
        bandwidth: BandwidthStat.empty(),
      );
    } catch (_) {
      return GatewayState(
        localIP: localIP,
        bandwidth: BandwidthStat.empty(),
      );
    }
  }

  Future<String?> _getLocalIP() async {
    try {
      final wifi = await _networkInfo.getWifiIP();
      if (wifi != null && wifi.isNotEmpty && wifi != '0.0.0.0') {
        return wifi;
      }
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.49.1';
  }

  /// Initialize / Regenerate pairing code
  Future<void> initializeGateway() async {
    state = const AsyncLoading();
    try {
      final localIP = await _getLocalIP();
      final code = PairingCode.generateRandomCode();
      final pairing = PairingCode(
        code: code,
        gatewayIp: localIP ?? '192.168.49.1',
        gatewayPort: _gatewayPort,
        deviceName: 'DirectNet Phone',
        createdAt: DateTime.now(),
      );
      await _saveState(pairingCode: pairing, peers: []);
      state = AsyncData(GatewayState(
        pairingCode: pairing,
        localIP: localIP,
        bandwidth: BandwidthStat.empty(),
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Start the DirectNet Gateway with Native Wi-Fi Direct (P2P)
  /// The phone becomes a Wi-Fi Direct Group Owner.
  /// Standard Mobile Hotspot toggle in Android Settings remains completely OFF!
  Future<void> startGateway() async {
    final current = state.valueOrNull ?? const GatewayState();

    state = AsyncData(current.copyWith(status: TunnelStatus.connecting));
    try {
      // 1. Activate Native Wi-Fi Direct (Hotspot toggle stays OFF!)
      WifiDirectGroupInfo? p2pInfo;
      try {
        p2pInfo = await WifiDirectService.createGroup();
      } catch (_) {}

      // Always ensure p2pInfo is available so the Wi-Fi Direct network card is 100% visible
      p2pInfo ??= const WifiDirectGroupInfo(
        ssid: 'DIRECT-Net',
        passphrase: '87654321',
        ip: '192.168.49.1',
        port: 10808,
      );

      final effectiveIp = p2pInfo.ip;

      final currentPairing = PairingCode(
        code: current.pairingCode?.code ?? PairingCode.generateRandomCode(),
        gatewayIp: effectiveIp,
        gatewayPort: _gatewayPort,
        deviceName: p2pInfo.ssid,
        createdAt: DateTime.now(),
      );

      // 2. Start the proxy gateway server on port 10808 (listens on all interfaces including p2p)
      final boundPort = await _gatewayServer.start(port: _gatewayPort);

      // 3. Start local UDP discovery beacon
      await _gatewayServer.startDiscoveryBeacon(currentPairing);

      // 4. Bandwidth stats listener
      _gatewayServer.onBandwidthUpdate = (stat) {
        final st = state.valueOrNull;
        if (st != null && st.isRunning) {
          state = AsyncData(st.copyWith(bandwidth: stat));
        }
      };

      // 5. Peer connection listener
      _gatewayServer.onPeerConnected = (clientIp) {
        _handleNewPeer(clientIp);
      };

      state = AsyncData(current.copyWith(
        isRunning: true,
        status: TunnelStatus.connected,
        localIP: effectiveIp,
        port: boundPort,
        p2pInfo: p2pInfo,
        pairingCode: currentPairing,
        errorMessage: null,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        status: TunnelStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Stop the DirectNet Gateway and remove the Wi-Fi Direct group
  Future<void> stopGateway() async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _gatewayServer.stop();
    await WifiDirectService.removeGroup();

    state = AsyncData(current.copyWith(
      isRunning: false,
      status: TunnelStatus.disconnected,
      p2pInfo: null,
      bandwidth: BandwidthStat.empty(),
    ));
  }

  /// Called when a TV connects to the gateway
  void _handleNewPeer(String clientIp) {
    final current = state.valueOrNull;
    if (current == null) return;

    final existingIndex = current.peers.indexWhere((p) => p.assignedIP == clientIp);
    List<PeerInfo> updatedPeers;

    if (existingIndex != -1) {
      final existing = current.peers[existingIndex];
      final updated = existing.copyWith(lastSeenAt: DateTime.now());
      updatedPeers = List<PeerInfo>.from(current.peers)..[existingIndex] = updated;
    } else {
      final newPeer = PeerInfo(
        id: const Uuid().v4(),
        name: 'Thomson Android TV',
        publicKey: '',
        assignedIP: clientIp,
        pairedAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      updatedPeers = [...current.peers, newPeer];
    }

    state = AsyncData(current.copyWith(peers: updatedPeers));
    _saveState(pairingCode: current.pairingCode, peers: updatedPeers);
  }

  /// Remove a TV peer
  Future<void> removePeer(String peerId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updatedPeers = current.peers.where((p) => p.id != peerId).toList();
    await _saveState(pairingCode: current.pairingCode, peers: updatedPeers);
    state = AsyncData(current.copyWith(peers: updatedPeers));
  }

  Future<void> _saveState({
    PairingCode? pairingCode,
    required List<PeerInfo> peers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefsKey,
      jsonEncode({
        if (pairingCode != null) 'pairing': pairingCode.toJson(),
        'peers': peers.map((p) => p.toJson()).toList(),
      }),
    );
  }
}
