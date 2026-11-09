import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/gateway/gateway_notifier.dart';
import '../../core/theme/app_theme.dart';

class PairingScreen extends ConsumerWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewayAsync = ref.watch(gatewayProvider);
    final colors = DirectNetColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Connect TV'),
        leading: BackButton(color: colors.accent),
      ),
      body: gatewayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (gateway) {
          final code = gateway.pairingCode?.code ?? '123456';
          final ip = gateway.localIP ?? '192.168.43.1';
          final port = gateway.port;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: colors.accent),
                      const Gap(6),
                      Text(
                        'SECURED CODE-BASED PAIRING',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                Text(
                  'Enter this code on your TV',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  'Open DirectNet TV app on your Thomson TV and type this 6-digit code using your remote:',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(28),

                // Big Code Display Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Individual digit boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < code.length; i++) ...[
                            if (i == 3) const Gap(14),
                            _DigitBox(
                              digit: code[i],
                              colors: colors,
                            ),
                            if (i != 2 && i != code.length - 1) const Gap(8),
                          ],
                        ],
                      ),
                      const Gap(20),

                      // Actions under code
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.accent,
                              side: BorderSide(color: colors.border),
                            ),
                          ),
                          const Gap(12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(gatewayProvider.notifier).initializeGateway();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('New Code'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              side: BorderSide(color: colors.border),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // ── TYPE THIS IP ON TV — prominent banner ───────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.15),
                        colors.success.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tv_rounded, color: colors.accent, size: 18),
                          const Gap(8),
                          Text(
                            'WI-FI DIRECT • HOTSPOT OFF ✓',
                            style: TextStyle(
                              color: colors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const Gap(10),
                      if (gateway.p2pInfo != null) ...[
                        Text(
                          '1. Connect TV to this Wi-Fi network:',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                        const Gap(4),
                        SelectableText(
                          'SSID: ${gateway.p2pInfo!.ssid}',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (gateway.p2pInfo!.passphrase.isNotEmpty) ...[
                          const Gap(2),
                          SelectableText(
                            'Password: ${gateway.p2pInfo!.passphrase}',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        const Gap(12),
                      ],
                      Text(
                        '2. Gateway IP Address:',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                      const Gap(4),
                      SelectableText(
                        '$ip:$port',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Gap(10),
                      Text(
                        'Your mobile hotspot switch stays OFF. All data transfers via direct Wi-Fi P2P!',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          _StatusPill(
                            label: gateway.isRunning ? 'Gateway Active ✓' : 'Gateway Offline — toggle ON',
                            color: gateway.isRunning ? colors.success : colors.warning,
                          ),
                          const Gap(10),
                          if (!gateway.isRunning)
                            GestureDetector(
                              onTap: () {
                                ref.read(gatewayProvider.notifier).startGateway();
                              },
                              child: _StatusPill(
                                label: 'Start Now →',
                                color: colors.accent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(28),

                // Instructions Card
                _InstructionSteps(colors: colors),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  final String digit;
  final DirectNetColors colors;

  const _DigitBox({required this.digit, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Text(
        digit,
        style: TextStyle(
          color: colors.accent,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _InstructionSteps extends StatelessWidget {
  final DirectNetColors colors;
  const _InstructionSteps({required this.colors});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Turn ON Gateway switch (Wi-Fi Direct starts with Hotspot OFF)'),
      ('2', 'On TV Settings ➔ Wi-Fi: Connect to the Direct Wi-Fi network shown above'),
      ('3', 'Open DirectNet TV app & enter 6-digit code (or auto-detect 192.168.49.1)'),
      ('4', 'Done! Unlimited Mobile 5G internet streams to TV with Hotspot OFF!'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: colors.accent),
              const Gap(8),
              Text(
                'How to connect',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Gap(16),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        s.$1,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
