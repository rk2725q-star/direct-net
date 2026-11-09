import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';
import '../../../core/gateway/gateway_notifier.dart';
import '../../../core/theme/app_theme.dart';

class GatewayToggleCard extends ConsumerWidget {
  final GatewayState gateway;
  const GatewayToggleCard({super.key, required this.gateway});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DirectNetColors.of(context);
    final isConnected = gateway.status == TunnelStatus.connected;
    final isConnecting = gateway.status == TunnelStatus.connecting;

    final statusColor = switch (gateway.status) {
      TunnelStatus.connected  => colors.success,
      TunnelStatus.connecting => colors.warning,
      TunnelStatus.error      => Theme.of(context).colorScheme.error,
      _                       => colors.textSecondary,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? colors.success.withValues(alpha: 0.4) : colors.border,
          width: isConnected ? 1.5 : 1,
        ),
        boxShadow: isConnected
            ? [BoxShadow(color: colors.success.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingDot(color: statusColor, animate: isConnected || isConnecting),
                const Gap(10),
                Text(
                  'Gateway Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch.adaptive(
                  value: gateway.isRunning,
                  activeThumbColor: colors.accent,
                  onChanged: isConnecting
                      ? null
                      : (val) {
                          if (val) {
                            ref.read(gatewayProvider.notifier).startGateway();
                          } else {
                            ref.read(gatewayProvider.notifier).stopGateway();
                          }
                        },
                ),
              ],
            ),
            const Gap(4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(gateway.status),
                gateway.status == TunnelStatus.connected
                    ? (gateway.p2pInfo != null
                        ? 'Active • Wi-Fi Direct (Hotspot OFF ✓)'
                        : 'Active • Sharing Mobile Internet')
                    : gateway.status.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: isConnected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (gateway.isRunning) ...[
              const Gap(16),
              const Divider(),
              const Gap(14),

              // Wi-Fi Direct P2P Network Card (Hotspot switch is OFF!)
              if (gateway.p2pInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.12),
                        colors.success.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_tethering_rounded, size: 16, color: colors.success),
                          const Gap(8),
                          Text(
                            'JIOFIBER 5G ROUTER MODE',
                            style: TextStyle(
                              color: colors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Hotspot OFF ✓',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(10),
                      Text(
                        'Connect TV, Mobiles & Laptops to this Wi-Fi:',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                      const Gap(6),
                      Row(
                        children: [
                          Text('Network: ', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                          SelectableText(
                            gateway.p2pInfo!.ssid,
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (gateway.p2pInfo!.passphrase.isNotEmpty) ...[
                        const Gap(4),
                        Row(
                          children: [
                            Text('Password: ', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                            SelectableText(
                              gateway.p2pInfo!.passphrase,
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Gap(10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.accent,
                          side: BorderSide(color: colors.accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: const Text('Show Wi-Fi QR Code (Scan to Connect)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          _showWifiQrDialog(context, gateway.p2pInfo!.ssid, gateway.p2pInfo!.passphrase, colors);
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(12),
              ],

              // 6-digit Pairing Code block
              if (gateway.pairingCode != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TV PAIRING CODE',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            gateway.pairingCode!.formattedCode,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        color: colors.accent,
                        tooltip: 'Copy Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: gateway.pairingCode!.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pairing code copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(12),
              ],

              Row(
                children: [
                  Icon(Icons.router_rounded, size: 16, color: colors.textSecondary),
                  const Gap(8),
                  Text('Gateway Address', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    '${gateway.localIP ?? "192.168.49.1"}:${gateway.port}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.accent,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  Icon(Icons.settings_ethernet_rounded, size: 16, color: colors.textSecondary),
                  const Gap(8),
                  Text('Router Proxy (Mobiles/Laptops)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                  const Spacer(),
                  Text(
                    '192.168.49.1 : 10808 / 8282',
                    style: TextStyle(
                      color: colors.accent,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Gap(8),
              Row(
                children: [
                  Icon(Icons.devices_rounded, size: 16, color: colors.textSecondary),
                  const Gap(8),
                  Text('Connected Devices', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    '${gateway.peers.length}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
            if (gateway.errorMessage != null) ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gateway.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWifiQrDialog(BuildContext context, String ssid, String password, DirectNetColors colors) {
    final wifiQrPayload = 'WIFI:T:WPA;S:$ssid;P:$password;;';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: colors.accent),
            const Gap(10),
            const Text('Scan Wi-Fi QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan with any phone camera or Wi-Fi scanner to connect automatically:',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: wifiQrPayload,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const Gap(16),
            Text(
              'Network: $ssid',
              style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Gap(4),
            Text(
              'Password: $password',
              style: TextStyle(color: colors.textSecondary, fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.animate
        ? ScaleTransition(
            scale: _scale,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          );
  }
}
