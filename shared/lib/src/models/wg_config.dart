import 'package:equatable/equatable.dart';

/// Represents a WireGuard peer configuration (TV device)
class WgPeerConfig extends Equatable {
  final String publicKey;
  final String allowedIPs;
  final String? endpoint; // optional for server-side
  final int? persistentKeepalive;

  const WgPeerConfig({
    required this.publicKey,
    required this.allowedIPs,
    this.endpoint,
    this.persistentKeepalive,
  });

  @override
  List<Object?> get props => [publicKey, allowedIPs, endpoint, persistentKeepalive];

  Map<String, dynamic> toJson() => {
    'publicKey': publicKey,
    'allowedIPs': allowedIPs,
    if (endpoint != null) 'endpoint': endpoint,
    if (persistentKeepalive != null) 'persistentKeepalive': persistentKeepalive,
  };

  factory WgPeerConfig.fromJson(Map<String, dynamic> json) => WgPeerConfig(
    publicKey: json['publicKey'] as String,
    allowedIPs: json['allowedIPs'] as String,
    endpoint: json['endpoint'] as String?,
    persistentKeepalive: json['persistentKeepalive'] as int?,
  );
}

/// Full WireGuard interface configuration (for a device — mobile or TV)
class WgInterfaceConfig extends Equatable {
  final String privateKey;
  final String publicKey;
  final String address; // e.g. "10.6.0.1/24" for mobile, "10.6.0.2/32" for TV
  final int listenPort;
  final List<String> dns;

  const WgInterfaceConfig({
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.listenPort,
    this.dns = const ['1.1.1.1', '8.8.8.8'],
  });

  @override
  List<Object?> get props => [privateKey, publicKey, address, listenPort, dns];

  Map<String, dynamic> toJson() => {
    'privateKey': privateKey,
    'publicKey': publicKey,
    'address': address,
    'listenPort': listenPort,
    'dns': dns,
  };

  factory WgInterfaceConfig.fromJson(Map<String, dynamic> json) => WgInterfaceConfig(
    privateKey: json['privateKey'] as String,
    publicKey: json['publicKey'] as String,
    address: json['address'] as String,
    listenPort: json['listenPort'] as int,
    dns: List<String>.from(json['dns'] as List),
  );
}

/// Full WireGuard configuration combining interface + peers
class WgConfig extends Equatable {
  final WgInterfaceConfig interface;
  final List<WgPeerConfig> peers;

  const WgConfig({
    required this.interface,
    this.peers = const [],
  });

  @override
  List<Object?> get props => [interface, peers];

  WgConfig copyWith({
    WgInterfaceConfig? interface,
    List<WgPeerConfig>? peers,
  }) =>
      WgConfig(
        interface: interface ?? this.interface,
        peers: peers ?? this.peers,
      );

  Map<String, dynamic> toJson() => {
    'interface': interface.toJson(),
    'peers': peers.map((p) => p.toJson()).toList(),
  };

  factory WgConfig.fromJson(Map<String, dynamic> json) => WgConfig(
    interface: WgInterfaceConfig.fromJson(json['interface'] as Map<String, dynamic>),
    peers: (json['peers'] as List)
        .map((p) => WgPeerConfig.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

