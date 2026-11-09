// WireGuard approach is ABANDONED — phone cannot VPN itself as a server.
// This file is kept as a stub so no imports break, but nothing here is called.
// The gateway is now a pure Dart ServerSocket proxy in gateway_server.dart.

/// Stub — not used. Kept only to avoid unused-file lint warnings from old references.
class WgTunnelService {
  Future<void> startServer(dynamic config) async {}
  Future<void> stop() async {}
  Future<void> reloadConfig(dynamic config) async {}
  Future<Map<String, DateTime>> getStats() async => {};
}
