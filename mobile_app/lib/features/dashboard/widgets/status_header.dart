import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/gateway/gateway_notifier.dart';
import '../../../core/theme/app_theme.dart';

class StatusHeader extends StatelessWidget {
  final GatewayState gateway;
  const StatusHeader({super.key, required this.gateway});

  @override
  Widget build(BuildContext context) {
    final colors = DirectNetColors.of(context);
    final onlinePeers = gateway.peers.where((p) => p.isOnline).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.12),
            colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DirectNet',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const Gap(4),
                Text(
                  gateway.isRunning
                      ? '$onlinePeers TV${onlinePeers != 1 ? "s" : ""} sharing your internet'
                      : 'Gateway is offline',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Signal icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (gateway.isRunning ? colors.accent : colors.textSecondary).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              gateway.isRunning
                  ? Icons.wifi_tethering_rounded
                  : Icons.wifi_tethering_off_rounded,
              color: gateway.isRunning ? colors.accent : colors.textSecondary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
