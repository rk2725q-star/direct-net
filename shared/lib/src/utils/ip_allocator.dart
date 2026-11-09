/// Allocates IP addresses within the DirectNet VPN subnet: 10.6.0.0/24
/// Mobile gateway always gets 10.6.0.1
/// TVs get 10.6.0.2 through 10.6.0.254
class IpAllocator {
  static const String subnetBase = '10.6.0';
  static const String gatewayIP = '10.6.0.1';
  static const String subnetMask = '10.6.0.0/24';

  /// Given a list of already-allocated IPs, return the next available IP
  static String allocateNext(List<String> usedIPs) {
    final usedLast = usedIPs
        .where((ip) => ip.startsWith('$subnetBase.'))
        .map((ip) => int.tryParse(ip.split('.').last) ?? 0)
        .toSet();

    for (var i = 2; i <= 254; i++) {
      if (!usedLast.contains(i)) {
        return '$subnetBase.$i';
      }
    }
    throw StateError('No more IP addresses available in subnet $subnetMask');
  }

  /// Check if an IP belongs to the DirectNet subnet
  static bool isInSubnet(String ip) => ip.startsWith('$subnetBase.');
}

