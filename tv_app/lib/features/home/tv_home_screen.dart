import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shared/shared.dart';
import '../../core/theme/tv_theme.dart';
import '../../core/tunnel/tv_tunnel_notifier.dart';

class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunnelAsync = ref.watch(tvTunnelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: tunnelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorBody(context, e.toString()),
        data: (state) => state.isPaired
            ? _ConnectedBody(state: state)
            : _UnpairedBody(),
      ),
    );
  }

  Widget _errorBody(BuildContext context, String error) => Center(
    child: Text('Error: $error',
      style: const TextStyle(color: Colors.redAccent, fontSize: 20)),
  );
}

// ── Unpaired state ────────────────────────────────────────────────────────────

class _UnpairedBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = TvColors.of(context);

    return Stack(
      children: [
        // Background grid pattern
        CustomPaint(painter: _GridPainter(colors.border), size: Size.infinite),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(Icons.wifi_tethering_rounded, size: 96, color: colors.accent),
              const Gap(32),
              Text(
                'DirectNet TV',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: colors.accent),
              ),
              const Gap(16),
              Text(
                'Share your mobile internet to this TV — no hotspot needed.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Gap(48),
              // D-pad focusable button
              _TvFocusButton(
                autofocus: true,
                onPressed: () => Navigator.pushNamed(context, '/pairing'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pin_rounded, size: 28, color: Colors.black),
                    const Gap(12),
                    Text(
                      'Connect with 6-Digit Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),
              Text(
                'Press OK on your remote to continue',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Connected state ───────────────────────────────────────────────────────────

class _ConnectedBody extends ConsumerWidget {
  final TvTunnelState state;
  const _ConnectedBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = TvColors.of(context);
    final isConnected = state.status == TunnelStatus.connected;
    final isConnecting = state.status == TunnelStatus.connecting;

    final statusColor = switch (state.status) {
      TunnelStatus.connected  => colors.success,
      TunnelStatus.connecting => colors.warning,
      TunnelStatus.error      => Theme.of(context).colorScheme.error,
      TunnelStatus.idle       => colors.warning,
      _                       => colors.textSecondary,
    };

    return Stack(
      children: [
        CustomPaint(painter: _GridPainter(colors.border), size: Size.infinite),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 48),
          child: Row(
            children: [
              // Left panel — status
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi_tethering_rounded, color: colors.accent, size: 40),
                        const Gap(16),
                        Text(
                          'DirectNet',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(color: colors.accent),
                        ),
                      ],
                    ),
                    const Gap(32),

                    // Big status indicator
                    _StatusPill(status: state.status, color: statusColor),
                    const Gap(20),

                    if (isConnected && state.pairingCode != null) ...[
                      _infoRow('Phone Gateway', '${state.pairingCode!.gatewayIp}:${state.pairingCode!.gatewayPort}', context, colors),
                      const Gap(10),
                      _infoRow('Pairing Code', state.pairingCode!.formattedCode, context, colors),
                      const Gap(10),
                      _infoRow('Ping / Latency', '${state.latencyMs ?? 15} ms (Fast)', context, colors),
                      const Gap(10),
                      _infoRow('All Apps Active', 'YouTube, Netflix, Prime, Hotstar, Play Store ✓', context, colors),
                      const Gap(10),
                      _infoRow('Manual Wi-Fi Proxy', '${state.pairingCode!.gatewayIp}:${state.pairingCode!.gatewayPort}', context, colors),
                    ],

                    if (state.errorMessage != null) ...[
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],

                    const Gap(40),

                    // Action buttons (D-pad focusable)
                    if (isConnecting)
                      const Row(children: [
                        SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                        Gap(16),
                        Text('Connecting to gateway...', style: TextStyle(fontSize: 20)),
                      ])
                    else
                      Row(
                        children: [
                          _TvFocusButton(
                            autofocus: true,
                            onPressed: isConnected
                                ? () => ref.read(tvTunnelProvider.notifier).disconnect()
                                : () => ref.read(tvTunnelProvider.notifier)
                                    .connectToGateway(state.pairingCode!),
                            backgroundColor: isConnected
                                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                                : colors.accent,
                            foregroundColor: isConnected
                                ? Theme.of(context).colorScheme.error
                                : Colors.black,
                            borderColor: isConnected
                                ? Theme.of(context).colorScheme.error
                                : null,
                            child: Text(
                              isConnected ? 'Disconnect' : 'Reconnect',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Gap(16),
                          _TvFocusButton(
                            onPressed: () {
                              _confirmForget(context, ref);
                            },
                            backgroundColor: Colors.transparent,
                            borderColor: colors.border,
                            foregroundColor: colors.textSecondary,
                            child: const Text('Forget & Re-pair',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const Gap(80),

              // Right panel — big connection visual
              Expanded(
                flex: 2,
                child: Center(
                  child: _ConnectionOrb(isConnected: isConnected, colors: colors),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmForget(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget Pairing?', style: TextStyle(fontSize: 28)),
        content: const Text(
          'This will remove the gateway configuration. You\'ll need to enter the pairing code again.',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 20)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tvTunnelProvider.notifier).forgetPairing();
            },
            child: const Text('Forget', style: TextStyle(color: Colors.redAccent, fontSize: 20)),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// A TV D-pad focusable button with highlight ring on focus
class _TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  const _TvFocusButton({
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = TvColors.of(context);
    final bg = widget.backgroundColor ?? colors.accent;
    final fg = widget.foregroundColor ?? Colors.black;
    final border = widget.borderColor;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _focused ? (bg == colors.accent ? colors.accent : bg.withValues(alpha: 0.2)) : bg.withValues(alpha: bg == colors.accent ? 1 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? colors.focus
                  : (border ?? bg.withValues(alpha: 0)),
              width: _focused ? 2.5 : 1,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: colors.focus.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)]
                : [],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: _focused ? (bg == colors.accent ? Colors.black : fg) : fg),
            child: IconTheme.merge(
              data: IconThemeData(color: _focused ? Colors.black : fg),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TunnelStatus status;
  final Color color;
  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const Gap(10),
          Text(
            status.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

Widget _infoRow(String label, String value, BuildContext context, TvColors colors) {
  return Row(
    children: [
      Text('$label:', style: Theme.of(context).textTheme.bodyMedium),
      const Gap(12),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colors.accent,
          fontFamily: 'monospace',
          fontSize: 18,
        ),
      ),
    ],
  );
}

class _ConnectionOrb extends StatefulWidget {
  final bool isConnected;
  final TvColors colors;
  const _ConnectionOrb({required this.isConnected, required this.colors});

  @override
  State<_ConnectionOrb> createState() => _ConnectionOrbState();
}

class _ConnectionOrbState extends State<_ConnectionOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
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
    final color = widget.isConnected ? widget.colors.success : widget.colors.textSecondary;

    return ScaleTransition(
      scale: widget.isConnected ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: widget.isConnected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 48, spreadRadius: 12)]
              : [],
        ),
        child: Icon(
          widget.isConnected ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
          size: 80,
          color: color,
        ),
      ),
    );
  }
}

// Background grid painter
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

