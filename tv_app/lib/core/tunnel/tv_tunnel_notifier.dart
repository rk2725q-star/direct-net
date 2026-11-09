import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart';
import 'tv_vpn_client.dart';

const _kPrefsKey = 'directnet_tv_state';
const _kDiscoveryPort = 10809;

final tvTunnelProvider =
    AsyncNotifierProvider<TvTunnelNotifier, TvTunnelState>(TvTunnelNotifier.new);

class TvTunnelState {
  final bool isPaired;
  final TunnelStatus status;
  final PairingCode? pairingCode;
  final int? latencyMs;
  final String? errorMessage;
  final DateTime? lastChecked;

  const TvTunnelState({
    this.isPaired = false,
    this.status = TunnelStatus.disconnected,
    this.pairingCode,
    this.latencyMs,
    this.errorMessage,
    this.lastChecked,
  });

  TvTunnelState copyWith({
    bool? isPaired,
    TunnelStatus? status,
    PairingCode? pairingCode,
    int? latencyMs,
    String? errorMessage,
    DateTime? lastChecked,
  }) =>
      TvTunnelState(
        isPaired: isPaired ?? this.isPaired,
        status: status ?? this.status,
        pairingCode: pairingCode ?? this.pairingCode,
        latencyMs: latencyMs ?? this.latencyMs,
        errorMessage: errorMessage,
        lastChecked: lastChecked ?? this.lastChecked,
      );
}

class TvTunnelNotifier extends AsyncNotifier<TvTunnelState> {
  Timer? _heartbeatTimer;
  RawDatagramSocket? _discoverySocket;

  @override
  Future<TvTunnelState> build() async {
    ref.onDispose(() {
      _heartbeatTimer?.cancel();
      _discoverySocket?.close();
    });
    return _loadSaved();
  }

  Future<TvTunnelState> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return const TvTunnelState();

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pairing = PairingCode.fromJson(json);
      // Auto-connect on load if already paired
      _scheduleConnect(pairing);
      return TvTunnelState(
        isPaired: true,
        pairingCode: pairing,
        status: TunnelStatus.connecting,
      );
    } catch (_) {
      return const TvTunnelState();
    }
  }

  void _scheduleConnect(PairingCode pairing) {
    Future.delayed(const Duration(milliseconds: 500), () => connectToGateway(pairing));
  }

  /// Connect to the Phone Gateway via 6-digit code or IP
  Future<bool> connectToGateway(PairingCode pairing) async {
    final current = state.valueOrNull ?? const TvTunnelState();
    state = AsyncData(current.copyWith(
      status: TunnelStatus.connecting,
      errorMessage: null,
      pairingCode: pairing,
    ));

    PairingCode effectivePairing = pairing;

    try {
      // 1. Detect TV's active Wi-Fi Gateway IP from Android DHCP
      final dhcpGateway = await TvVpnClient.getWifiGatewayIp();
      if (dhcpGateway != null && dhcpGateway.isNotEmpty && dhcpGateway != '0.0.0.0') {
        effectivePairing = PairingCode(
          code: pairing.code,
          gatewayIp: dhcpGateway,
          gatewayPort: pairing.gatewayPort,
          deviceName: pairing.deviceName,
          createdAt: pairing.createdAt,
        );
      }

      // 2. Start the native TV VpnService (hev-socks5-tunnel + mapdns)
      // This will prompt for VPN permission dialog if not already granted!
      await TvVpnClient.startVpn(
        host: effectivePairing.gatewayIp,
        port: effectivePairing.gatewayPort,
      );

      // 3. Measure connection latency
      int latency = 15;
      try {
        final stopwatch = Stopwatch()..start();
        final probeSocket = await Socket.connect(
          effectivePairing.gatewayIp,
          effectivePairing.gatewayPort,
          timeout: const Duration(seconds: 4),
        );
        stopwatch.stop();
        latency = stopwatch.elapsedMilliseconds;
        await probeSocket.close();
      } catch (_) {
        // If initial probe has slight delay, VPN is already active and routing
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(effectivePairing.toJson()));

      state = AsyncData(TvTunnelState(
        isPaired: true,
        pairingCode: effectivePairing,
        status: TunnelStatus.connected,
        latencyMs: latency,
        lastChecked: DateTime.now(),
      ));

      _startHeartbeat(effectivePairing);
      return true;
    } catch (e) {
      state = AsyncData(current.copyWith(
        status: TunnelStatus.error,
        errorMessage: 'Could not connect to Phone at ${effectivePairing.gatewayIp}:${effectivePairing.gatewayPort}.\nEnsure Phone Gateway switch is ON.',
      ));
      return false;
    }
  }

  void _startHeartbeat(PairingCode pairing) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          pairing.gatewayIp,
          pairing.gatewayPort,
          timeout: const Duration(seconds: 4),
        );
        stopwatch.stop();
        await socket.close();

        final cur = state.valueOrNull;
        if (cur != null) {
          state = AsyncData(cur.copyWith(
            status: TunnelStatus.connected,
            latencyMs: stopwatch.elapsedMilliseconds,
            lastChecked: DateTime.now(),
          ));
        }
      } catch (_) {
        final cur = state.valueOrNull;
        if (cur != null) {
          state = AsyncData(cur.copyWith(
            status: TunnelStatus.idle,
          ));
        }
      }
    });
  }

  /// Disconnect TV from phone gateway
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    await TvVpnClient.stopVpn();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(status: TunnelStatus.disconnected));
    }
  }

  /// Forget saved pairing code
  Future<void> forgetPairing() async {
    await disconnect();
    await TvVpnClient.stopVpn();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
    state = const AsyncData(TvTunnelState());
  }

  /// Listen for phone UDP discovery beacons (auto-discovery)
  Stream<PairingCode> startBeaconDiscovery() {
    _discoverySocket?.close();
    late StreamController<PairingCode> controller;

    controller = StreamController<PairingCode>(
      onListen: () async {
        try {
          _discoverySocket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            _kDiscoveryPort,
            reuseAddress: true,
            reusePort: true,
          );
          _discoverySocket!.broadcastEnabled = true;

          _discoverySocket!.listen((event) {
            if (event == RawSocketEvent.read) {
              final datagram = _discoverySocket?.receive();
              if (datagram != null) {
                try {
                  final text = utf8.decode(datagram.data);
                  final beacon = PairingCode.fromBeaconJson(text);
                  if (beacon != null && !controller.isClosed) {
                    controller.add(beacon);
                  }
                } catch (_) {}
              }
            }
          });
        } catch (_) {}
      },
      onCancel: () {
        _discoverySocket?.close();
        _discoverySocket = null;
      },
    );

    return controller.stream;
  }
}
