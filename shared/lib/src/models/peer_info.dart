import 'package:equatable/equatable.dart';

/// Represents a connected TV peer on the mobile gateway
class PeerInfo extends Equatable {
  final String id;         // UUID
  final String name;       // e.g. "Thomson TV"
  final String publicKey;  // WireGuard public key
  final String assignedIP; // e.g. "10.6.0.2"
  final DateTime pairedAt;
  final DateTime? lastSeenAt;

  const PeerInfo({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.assignedIP,
    required this.pairedAt,
    this.lastSeenAt,
  });

  bool get isOnline {
    if (lastSeenAt == null) return false;
    return DateTime.now().difference(lastSeenAt!).inSeconds < 30;
  }

  @override
  List<Object?> get props => [id, publicKey, assignedIP];

  PeerInfo copyWith({
    String? id,
    String? name,
    String? publicKey,
    String? assignedIP,
    DateTime? pairedAt,
    DateTime? lastSeenAt,
  }) =>
      PeerInfo(
        id: id ?? this.id,
        name: name ?? this.name,
        publicKey: publicKey ?? this.publicKey,
        assignedIP: assignedIP ?? this.assignedIP,
        pairedAt: pairedAt ?? this.pairedAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'publicKey': publicKey,
    'assignedIP': assignedIP,
    'pairedAt': pairedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
  };

  factory PeerInfo.fromJson(Map<String, dynamic> json) => PeerInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    publicKey: json['publicKey'] as String,
    assignedIP: json['assignedIP'] as String,
    pairedAt: DateTime.parse(json['pairedAt'] as String),
    lastSeenAt: json['lastSeenAt'] != null
        ? DateTime.parse(json['lastSeenAt'] as String)
        : null,
  );
}

