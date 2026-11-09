import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';

typedef OnBandwidthUpdate = void Function(BandwidthStat stat);
typedef OnPeerConnected = void Function(String clientIp);

/// High-performance DirectNet Gateway Server.
/// Runs in pure Dart on the phone — zero platform exceptions, zero root required.
/// Forwards HTTP, HTTPS (CONNECT tunneling for 4K streaming), and SOCKS5 (RFC 1928 TCP + UDP Associate).
///
/// Architected with a single-subscription stream model to eliminate
/// "Bad state: Stream has already been listened to" errors completely.
class GatewayServer {
  static const int defaultPort = 10808;
  static const int discoveryPort = 10809;

  ServerSocket? _serverSocket;
  ServerSocket? _legacyServerSocket;
  RawDatagramSocket? _broadcastSocket;
  Timer? _beaconTimer;
  Timer? _statsTimer;

  bool get isRunning => _serverSocket != null;

  int _totalUploadBytes = 0;
  int _totalDownloadBytes = 0;
  int _bytesUploadedLastSec = 0;
  int _bytesDownloadedLastSec = 0;

  final Set<String> _connectedPeers = {};
  final Set<_ProxySession> _sessions = {};

  OnBandwidthUpdate? onBandwidthUpdate;
  OnPeerConnected? onPeerConnected;

  void recordUpload(int bytes) {
    _totalUploadBytes += bytes;
    _bytesUploadedLastSec += bytes;
  }

  void recordDownload(int bytes) {
    _totalDownloadBytes += bytes;
    _bytesDownloadedLastSec += bytes;
  }

  /// Start the gateway server on [port] (default: 10808)
  Future<int> start({int port = defaultPort}) async {
    if (_serverSocket != null) return _serverSocket!.port;

    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );

    _serverSocket!.listen(
      _handleClientConnection,
      onError: (_) {
        // Silently continue accepting others
      },
      cancelOnError: false,
    );

    // Also bind port 8282 for NetShare compatibility & dual-port support
    try {
      _legacyServerSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        8282,
        shared: true,
      );
      _legacyServerSocket!.listen(
        _handleClientConnection,
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}

    _startStatsTicker();
    return _serverSocket!.port;
  }

  /// Start UDP broadcast beacon so the TV can auto-discover the phone
  Future<void> startDiscoveryBeacon(PairingCode pairingCode) async {
    stopDiscoveryBeacon();
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _broadcastSocket!.broadcastEnabled = true;

      final beaconBytes = utf8.encode(pairingCode.toBeaconJson());

      // Compute subnet broadcast (e.g. 192.168.49.255) in addition to 255.255.255.255
      InternetAddress? subnetBcast;
      final ipParts = pairingCode.gatewayIp.split('.');
      if (ipParts.length == 4) {
        try {
          subnetBcast = InternetAddress('${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.255');
        } catch (_) {}
      }

      // Broadcast every 2 seconds
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        try {
          _broadcastSocket?.send(
            beaconBytes,
            InternetAddress('255.255.255.255'),
            discoveryPort,
          );
          if (subnetBcast != null) {
            _broadcastSocket?.send(
              beaconBytes,
              subnetBcast,
              discoveryPort,
            );
          }
        } catch (_) {}
      });
    } catch (_) {
      // Beacon fails if network forbids broadcast; code entry is the reliable fallback
    }
  }

  void stopDiscoveryBeacon() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  /// Stop the gateway and release all sockets
  Future<void> stop() async {
    stopDiscoveryBeacon();
    _statsTimer?.cancel();
    _statsTimer = null;

    for (final session in List<_ProxySession>.from(_sessions)) {
      session.close();
    }
    _sessions.clear();
    _connectedPeers.clear();

    await _serverSocket?.close();
    _serverSocket = null;
    await _legacyServerSocket?.close();
    _legacyServerSocket = null;

    _totalUploadBytes = 0;
    _totalDownloadBytes = 0;
    _bytesUploadedLastSec = 0;
    _bytesDownloadedLastSec = 0;
  }

  void _startStatsTicker() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final uploadSpeed = _bytesUploadedLastSec.toDouble();
      final downloadSpeed = _bytesDownloadedLastSec.toDouble();

      _bytesUploadedLastSec = 0;
      _bytesDownloadedLastSec = 0;

      onBandwidthUpdate?.call(BandwidthStat(
        uploadBytesPerSec: uploadSpeed,
        downloadBytesPerSec: downloadSpeed,
        totalUploadBytes: _totalUploadBytes,
        totalDownloadBytes: _totalDownloadBytes,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _handleClientConnection(Socket client) {
    try {
      client.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    final clientIp = client.remoteAddress.address;
    if (_connectedPeers.add(clientIp)) {
      onPeerConnected?.call(clientIp);
    }

    final session = _ProxySession(client: client, server: this);
    _sessions.add(session);
    session.onClosed = () {
      _sessions.remove(session);
    };
  }
}

/// Manages a single client connection with a single continuous stream subscription.
enum _SessionState {
  detecting,
  socks5Greeting,
  socks5Request,
  tunneling,
  udpAssociated,
  closed,
}

class _ProxySession {
  final Socket client;
  final GatewayServer server;
  VoidCallback? onClosed;

  _SessionState _state = _SessionState.detecting;
  final List<int> _buffer = [];
  Socket? _remote;
  RawDatagramSocket? _udpSocket;
  InternetAddress? _clientUdpAddr;
  int? _clientUdpPort;

  StreamSubscription<Uint8List>? _clientSub;
  StreamSubscription<Uint8List>? _remoteSub;

  _ProxySession({required this.client, required this.server}) {
    try {
      client.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}

    _clientSub = client.listen(
      _onClientData,
      onError: (_) => close(),
      onDone: close,
      cancelOnError: true,
    );
  }

  void _onClientData(Uint8List data) {
    if (_state == _SessionState.closed) return;

    if (_state == _SessionState.tunneling) {
      // Direct pass-through to remote TCP
      server.recordUpload(data.length);
      try {
        _remote?.add(data);
      } catch (_) {
        close();
      }
      return;
    }

    if (_state == _SessionState.udpAssociated) {
      // SOCKS5 TCP control connection for UDP ASSOCIATE remains idle
      return;
    }

    _buffer.addAll(data);

    if (_state == _SessionState.detecting) {
      if (_buffer.isEmpty) return;

      // SOCKS5 starts with byte 0x05
      if (_buffer[0] == 0x05) {
        _state = _SessionState.socks5Greeting;
        _processSocks5Greeting();
      } else {
        // HTTP or HTTPS CONNECT
        _processHttp();
      }
    } else if (_state == _SessionState.socks5Greeting) {
      _processSocks5Greeting();
    } else if (_state == _SessionState.socks5Request) {
      _processSocks5Request();
    }
  }

  // ── SOCKS5 Handshake & Connection (RFC 1928) ───────────────────────────────

  void _processSocks5Greeting() {
    // Greeting structure: [0x05, NMETHODS, METHOD_1, METHOD_2, ...]
    if (_buffer.length < 2) return;
    final nMethods = _buffer[1];
    final totalGreetingLen = 2 + nMethods;
    if (_buffer.length < totalGreetingLen) return;

    // Remaining data (if client pipelined the request in the same packet)
    final remainder = _buffer.length > totalGreetingLen
        ? _buffer.sublist(totalGreetingLen)
        : <int>[];
    _buffer.clear();

    try {
      // Respond: VER=0x05, METHOD=0x00 (NO AUTH REQUIRED)
      client.add(const [0x05, 0x00]);
      client.flush();
    } catch (_) {
      close();
      return;
    }

    _state = _SessionState.socks5Request;

    if (remainder.isNotEmpty) {
      _buffer.addAll(remainder);
      _processSocks5Request();
    }
  }

  Future<void> _processSocks5Request() async {
    // SOCKS5 request:
    // [0x05, CMD, 0x00, ATYP, ... DST.ADDR ..., DST.PORT (2 bytes)]
    if (_buffer.length < 7) return;

    final cmd = _buffer[1];
    final atyp = _buffer[3];
    String targetHost = '';
    int targetPort = 0;
    int totalReqLen = 0;

    if (atyp == 0x01) {
      // IPv4: 4 bytes addr + 2 bytes port = 10 bytes total
      if (_buffer.length < 10) return;
      targetHost = '${_buffer[4]}.${_buffer[5]}.${_buffer[6]}.${_buffer[7]}';
      targetPort = (_buffer[8] << 8) | _buffer[9];
      totalReqLen = 10;
    } else if (atyp == 0x03) {
      // Domain name: 1 byte len + domain bytes + 2 bytes port
      final domainLen = _buffer[4];
      totalReqLen = 5 + domainLen + 2;
      if (_buffer.length < totalReqLen) return;
      try {
        targetHost = utf8.decode(_buffer.sublist(5, 5 + domainLen));
      } catch (_) {
        targetHost = String.fromCharCodes(_buffer.sublist(5, 5 + domainLen));
      }
      final portOffset = 5 + domainLen;
      targetPort = (_buffer[portOffset] << 8) | _buffer[portOffset + 1];
    } else if (atyp == 0x04) {
      // IPv6: 16 bytes addr + 2 bytes port = 22 bytes total
      if (_buffer.length < 22) return;
      final parts = <String>[];
      for (int i = 0; i < 16; i += 2) {
        final val = (_buffer[4 + i] << 8) | _buffer[5 + i];
        parts.add(val.toRadixString(16));
      }
      targetHost = parts.join(':');
      targetPort = (_buffer[20] << 8) | _buffer[21];
      totalReqLen = 22;
    } else {
      close();
      return;
    }

    if (cmd == 0x03) {
      // ── RFC 1928: UDP ASSOCIATE (Enables YouTube QUIC & DNS UDP Relay) ──────
      await _handleSocks5UdpAssociate();
      return;
    }

    if (cmd != 0x01) {
      // RFC 1928 SOCKS5 status 0x07 (Command not supported)
      try {
        client.add(const [0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await client.flush();
      } catch (_) {}
      close();
      return;
    }

    // ── RFC 1928: TCP CONNECT ────────────────────────────────────────────────
    final initialPayload = _buffer.length > totalReqLen
        ? Uint8List.fromList(_buffer.sublist(totalReqLen))
        : null;
    _buffer.clear();

    try {
      _remote = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 10));
      try {
        _remote!.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}

      // SOCKS5 success reply: 05 00 00 01 [bind addr 0.0.0.0] [bind port 00 00]
      client.add(const [0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      await client.flush();

      _state = _SessionState.tunneling;

      // Forward any pipelined payload to remote
      if (initialPayload != null && initialPayload.isNotEmpty) {
        server.recordUpload(initialPayload.length);
        _remote!.add(initialPayload);
      }

      _startRemoteListener();
    } catch (_) {
      try {
        client.add(const [0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await client.flush();
      } catch (_) {}
      close();
    }
  }

  Future<void> _handleSocks5UdpAssociate() async {
    _buffer.clear();
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final assignedPort = _udpSocket!.port;

      // Local address to inform client
      var rawIp = client.address.rawAddress;
      if (rawIp.length != 4) {
        rawIp = Uint8List.fromList([192, 168, 49, 1]);
      }

      // SOCKS5 UDP ASSOCIATE success response: 05 00 00 01 [BND.ADDR 4 bytes] [BND.PORT 2 bytes]
      client.add([
        0x05, 0x00, 0x00, 0x01,
        rawIp[0], rawIp[1], rawIp[2], rawIp[3],
        (assignedPort >> 8) & 0xFF, assignedPort & 0xFF,
      ]);
      await client.flush();

      _state = _SessionState.udpAssociated;

      _udpSocket!.listen(
        _onUdpDatagram,
        onError: (_) => close(),
        onDone: close,
      );
    } catch (_) {
      try {
        client.add(const [0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        await client.flush();
      } catch (_) {}
      close();
    }
  }

  void _onUdpDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _state == _SessionState.closed) return;
    final sock = _udpSocket;
    if (sock == null) return;

    final dg = sock.receive();
    if (dg == null || dg.data.isEmpty) return;

    final data = dg.data;

    // Check if packet came from client (TV/App) or internet server
    // RFC 1928 SOCKS5 UDP header: [RSV (2B: 0x00 0x00), FRAG (1B), ATYP (1B), DST.ADDR, DST.PORT, DATA...]
    final isClientPacket = data.length >= 10 && data[0] == 0x00 && data[1] == 0x00;

    if (isClientPacket) {
      _clientUdpAddr = dg.address;
      _clientUdpPort = dg.port;

      final atyp = data[3];
      InternetAddress? targetIp;
      int targetPort = 0;
      int headerLen = 0;

      if (atyp == 0x01) {
        // IPv4 (10B header)
        if (data.length < 10) return;
        targetIp = InternetAddress('${data[4]}.${data[5]}.${data[6]}.${data[7]}');
        targetPort = (data[8] << 8) | data[9];
        headerLen = 10;
      } else if (atyp == 0x03) {
        // Domain
        final domainLen = data[4];
        headerLen = 5 + domainLen + 2;
        if (data.length < headerLen) return;
        final domain = String.fromCharCodes(data.sublist(5, 5 + domainLen));
        targetPort = (data[5 + domainLen] << 8) | data[5 + domainLen + 1];
        targetIp = InternetAddress.tryParse(domain);
      } else if (atyp == 0x04) {
        // IPv6 (22B header)
        if (data.length < 22) return;
        final parts = <String>[];
        for (int i = 0; i < 16; i += 2) {
          parts.add(((data[4 + i] << 8) | data[5 + i]).toRadixString(16));
        }
        targetIp = InternetAddress(parts.join(':'));
        targetPort = (data[20] << 8) | data[21];
        headerLen = 22;
      }

      if (targetPort <= 0 || data.length <= headerLen) return;
      final payload = data.sublist(headerLen);

      server.recordUpload(payload.length);

      if (targetIp != null) {
        try {
          sock.send(payload, targetIp, targetPort);
        } catch (_) {}
      } else if (atyp == 0x03) {
        final domainLen = data[4];
        final domain = String.fromCharCodes(data.sublist(5, 5 + domainLen));
        InternetAddress.lookup(domain).then((addresses) {
          if (addresses.isNotEmpty && _state != _SessionState.closed && _udpSocket != null) {
            try {
              _udpSocket!.send(payload, addresses.first, targetPort);
            } catch (_) {}
          }
        }).catchError((_) {});
      }
    } else {
      // Inbound response from internet -> Deliver to client with SOCKS5 UDP header
      if (_clientUdpAddr == null || _clientUdpPort == null) return;

      server.recordDownload(data.length);

      final srcIp = dg.address.rawAddress;
      final srcPort = dg.port;

      if (srcIp.length == 4) {
        final header = Uint8List(10);
        header[0] = 0x00;
        header[1] = 0x00;
        header[2] = 0x00; // FRAG
        header[3] = 0x01; // ATYP IPv4
        header[4] = srcIp[0];
        header[5] = srcIp[1];
        header[6] = srcIp[2];
        header[7] = srcIp[3];
        header[8] = (srcPort >> 8) & 0xFF;
        header[9] = srcPort & 0xFF;

        final wrapped = Uint8List(10 + data.length);
        wrapped.setRange(0, 10, header);
        wrapped.setRange(10, wrapped.length, data);

        try {
          sock.send(wrapped, _clientUdpAddr!, _clientUdpPort!);
        } catch (_) {}
      }
    }
  }

  // ── HTTP & HTTPS CONNECT Proxying ──────────────────────────────────────────

  static (String, int) _parseHostPort(String input, int defaultPort) {
    input = input.trim();
    if (input.startsWith('[')) {
      final end = input.indexOf(']');
      if (end != -1) {
        final host = input.substring(1, end);
        final rest = input.substring(end + 1);
        final colon = rest.indexOf(':');
        final port = colon != -1 ? int.tryParse(rest.substring(colon + 1)) ?? defaultPort : defaultPort;
        return (host, port);
      }
    }
    final colon = input.lastIndexOf(':');
    if (colon != -1) {
      final host = input.substring(0, colon);
      final port = int.tryParse(input.substring(colon + 1)) ?? defaultPort;
      return (host, port);
    }
    return (input, defaultPort);
  }

  void _processHttp() {
    final raw = String.fromCharCodes(_buffer);
    final headerEnd = raw.indexOf('\r\n\r\n');
    final altHeaderEnd = raw.indexOf('\n\n');

    if (headerEnd == -1 && altHeaderEnd == -1) {
      // Wait for complete headers
      return;
    }

    final headerLen = headerEnd != -1 ? headerEnd + 4 : altHeaderEnd + 2;
    final leftover = _buffer.length > headerLen
        ? Uint8List.fromList(_buffer.sublist(headerLen))
        : null;
    final fullBuffer = Uint8List.fromList(_buffer.sublist(0, headerLen));
    _buffer.clear();

    final firstLineEnd = raw.indexOf('\n');
    if (firstLineEnd == -1) {
      close();
      return;
    }

    final firstLine = raw.substring(0, firstLineEnd).trim();
    final parts = firstLine.split(' ');
    if (parts.length < 2) {
      close();
      return;
    }

    final method = parts[0].toUpperCase();
    final target = parts[1];

    if (method == 'CONNECT') {
      _handleConnectTunnel(target, leftover);
    } else {
      _handlePlainHttp(target, fullBuffer);
    }
  }

  Future<void> _handleConnectTunnel(String hostPort, Uint8List? initialPayload) async {
    final (host, port) = _parseHostPort(hostPort, 443);

    try {
      _remote = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      try {
        _remote!.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}

      client.write('HTTP/1.1 200 Connection Established\r\nProxy-Agent: DirectNet/1.0\r\n\r\n');
      await client.flush();

      _state = _SessionState.tunneling;

      // Forward TLS ClientHello / pipelined data immediately
      if (initialPayload != null && initialPayload.isNotEmpty) {
        server.recordUpload(initialPayload.length);
        _remote!.add(initialPayload);
      }

      _startRemoteListener();
    } catch (_) {
      try {
        client.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await client.flush();
      } catch (_) {}
      close();
    }
  }

  Future<void> _handlePlainHttp(String target, Uint8List fullHeaderBytes) async {
    final raw = String.fromCharCodes(fullHeaderBytes);

    String host = '';
    int port = 80;
    String requestPath = target;

    if (target.startsWith('http://') || target.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null && uri.host.isNotEmpty) {
        host = uri.host;
        port = uri.hasPort ? uri.port : (target.startsWith('https://') ? 443 : 80);
        requestPath = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
        if (requestPath.isEmpty) requestPath = '/';
      }
    }

    if (host.isEmpty) {
      // Extract from Host: header
      final lines = raw.split('\r\n');
      for (final line in lines) {
        if (line.toLowerCase().startsWith('host:')) {
          final hostVal = line.substring(5).trim();
          final (h, p) = _parseHostPort(hostVal, 80);
          host = h;
          port = p;
          break;
        }
      }
    }

    // 1. Windows Captive Portal NCSI probes (msftconnecttest.com / msftncsi.com / ncsi.txt)
    if (host.contains('msftconnecttest') || host.contains('msftncsi') || requestPath.contains('ncsi.txt') || requestPath.contains('connecttest.txt')) {
      try {
        client.write('HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 14\r\nConnection: close\r\n\r\nMicrosoft NCSI');
        await client.flush();
      } catch (_) {}
      close();
      return;
    }

    // 2. Android Captive Portal check (generate_204)
    if (host.contains('connectivitycheck') || host.contains('generate_204') || requestPath.contains('generate_204')) {
      try {
        client.write('HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');
        await client.flush();
      } catch (_) {}
      close();
      return;
    }

    // 3. Apple Captive Portal check (captive.apple.com / hotspot-detect.html)
    if (host.contains('captive.apple.com') || requestPath.contains('hotspot-detect.html')) {
      const appleResp = '<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>';
      try {
        client.write('HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${appleResp.length}\r\nConnection: close\r\n\r\n$appleResp');
        await client.flush();
      } catch (_) {}
      close();
      return;
    }

    if (host.isEmpty) {
      host = '127.0.0.1';
    }

    try {
      _remote = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      try {
        _remote!.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}

      // Normalize headers: replace absolute target with relative path, convert Proxy-Connection to Connection
      var cleanHeaders = raw;
      if (target != requestPath && target.startsWith('http')) {
        cleanHeaders = cleanHeaders.replaceFirst(target, requestPath);
      }
      cleanHeaders = cleanHeaders.replaceAll(RegExp(r'Proxy-Connection:', caseSensitive: false), 'Connection:');

      final payload = utf8.encode(cleanHeaders);
      server.recordUpload(payload.length);
      _remote!.add(payload);

      _state = _SessionState.tunneling;
      _startRemoteListener();
    } catch (_) {
      try {
        client.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await client.flush();
      } catch (_) {}
      close();
    }
  }

  // ── Remote listener (Internet -> TV) ───────────────────────────────────────

  void _startRemoteListener() {
    _remoteSub = _remote?.listen(
      (data) {
        if (_state == _SessionState.closed) return;
        server.recordDownload(data.length);
        try {
          client.add(data);
        } catch (_) {
          close();
        }
      },
      onError: (_) => close(),
      onDone: close,
      cancelOnError: true,
    );
  }

  void close() {
    if (_state == _SessionState.closed) return;
    _state = _SessionState.closed;

    _clientSub?.cancel();
    _clientSub = null;

    _remoteSub?.cancel();
    _remoteSub = null;

    try {
      _udpSocket?.close();
    } catch (_) {}
    _udpSocket = null;

    try {
      client.destroy();
    } catch (_) {}

    try {
      _remote?.destroy();
    } catch (_) {}
    _remote = null;

    onClosed?.call();
  }
}
