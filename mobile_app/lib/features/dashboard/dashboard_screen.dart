import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/gateway/gateway_notifier.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/gateway_toggle_card.dart';
import 'widgets/peer_list_card.dart';
import 'widgets/bandwidth_chart_card.dart';
import 'widgets/status_header.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewayAsync = ref.watch(gatewayProvider);
    final colors = DirectNetColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.wifi_tethering_rounded, color: colors.accent, size: 28),
        ),
        title: const Text('DirectNet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          const Gap(8),
        ],
      ),
      body: gatewayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(error: e.toString()),
        data: (gateway) => _DashboardBody(gateway: gateway),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/pairing'),
        backgroundColor: colors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.pin_rounded),
        label: const Text('Pairing Code', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final GatewayState gateway;
  const _DashboardBody({required this.gateway});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(gatewayProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          StatusHeader(gateway: gateway),
          const Gap(16),
          GatewayToggleCard(gateway: gateway),
          const Gap(16),
          if (gateway.isRunning) ...[
            BandwidthChartCard(peers: gateway.peers),
            const Gap(16),
          ],
          PeerListCard(
            peers: gateway.peers,
            onRemovePeer: (id) =>
                ref.read(gatewayProvider.notifier).removePeer(id),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}
