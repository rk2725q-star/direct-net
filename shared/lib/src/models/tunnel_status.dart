/// Current state of the WireGuard tunnel
enum TunnelStatus {
  /// Not started / no config
  disconnected,

  /// Attempting to establish the tunnel
  connecting,

  /// Tunnel is active and routing traffic
  connected,

  /// Tunnel is active but no handshake in last 3 minutes (stale)
  idle,

  /// An error occurred
  error,
}

extension TunnelStatusX on TunnelStatus {
  String get label => switch (this) {
    TunnelStatus.disconnected => 'Disconnected',
    TunnelStatus.connecting   => 'Connecting...',
    TunnelStatus.connected    => 'Connected',
    TunnelStatus.idle         => 'Idle',
    TunnelStatus.error        => 'Error',
  };

  bool get isActive => this == TunnelStatus.connected || this == TunnelStatus.idle;
}

