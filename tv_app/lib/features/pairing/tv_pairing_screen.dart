import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shared/shared.dart';
import '../../core/theme/tv_theme.dart';
import '../../core/tunnel/tv_tunnel_notifier.dart';
import '../../core/tunnel/tv_vpn_client.dart';

/// Which "mode" the right keypad is currently controlling
enum _KeypadMode { code, ip }

class TvPairingScreen extends ConsumerStatefulWidget {
  const TvPairingScreen({super.key});

  @override
  ConsumerState<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends ConsumerState<TvPairingScreen> {
  String _enteredCode = '';

  /// IP typed by the user via D-pad keypad (defaults to standard Wi-Fi Direct IP 192.168.49.1)
  String _enteredIp = '192.168.49.1';

  /// Whether we are currently editing the code or the IP
  _KeypadMode _keypadMode = _KeypadMode.code;

  bool _connecting = false;
  String? _error;
  PairingCode? _discoveredPhone;
  StreamSubscription? _beaconSub;

  @override
  void initState() {
    super.initState();
    _startBeaconListener();
    _detectGatewayIp();
  }

  void _detectGatewayIp() {
    TvVpnClient.getWifiGatewayIp().then((ip) {
      if (ip != null && ip.isNotEmpty && ip != '0.0.0.0' && mounted) {
        setState(() {
          _enteredIp = ip;
        });
      }
    });
  }

  void _startBeaconListener() {
    _beaconSub = ref
        .read(tvTunnelProvider.notifier)
        .startBeaconDiscovery()
        .listen((beacon) {
      if (mounted) {
        setState(() {
          _discoveredPhone = beacon;
          // Auto-fill IP from beacon if user hasn't typed one yet
          if (_enteredIp.isEmpty) {
            _enteredIp = beacon.gatewayIp;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _beaconSub?.cancel();
    super.dispose();
  }

  // ── Code keypad handlers ───────────────────────────────────────────────────

  void _onDigitPressedForCode(String digit) {
    if (_enteredCode.length < 6) {
      setState(() {
        _enteredCode += digit;
        _error = null;
      });
    }
  }

  void _onCodeBackspace() {
    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
        _error = null;
      });
    }
  }

  void _onCodeClear() {
    setState(() {
      _enteredCode = '';
      _error = null;
    });
  }

  // ── IP keypad handlers ─────────────────────────────────────────────────────

  void _onIpChar(String ch) {
    // Limit: max 15 chars (e.g. "255.255.255.255")
    if (_enteredIp.length < 15) {
      setState(() {
        _enteredIp += ch;
        _error = null;
      });
    }
  }

  void _onIpBackspace() {
    if (_enteredIp.isNotEmpty) {
      setState(() {
        _enteredIp = _enteredIp.substring(0, _enteredIp.length - 1);
        _error = null;
      });
    }
  }

  void _onIpClear() {
    setState(() {
      _enteredIp = '';
      _error = null;
    });
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<void> _submitConnect([PairingCode? direct]) async {
    if (_enteredCode.length < 6 && direct == null) {
      setState(() => _error = 'Please enter all 6 digits of the pairing code.');
      return;
    }

    // Determine which IP to use: direct > entered IP (visible on screen) > beacon > error
    String effectiveIp;
    int effectivePort = 10808;

    if (direct != null) {
      effectiveIp = direct.gatewayIp;
      effectivePort = direct.gatewayPort;
    } else if (_enteredIp.isNotEmpty) {
      effectiveIp = _enteredIp.trim();
      effectivePort = _discoveredPhone?.gatewayPort ?? 10808;
    } else if (_discoveredPhone != null) {
      effectiveIp = _discoveredPhone!.gatewayIp;
      effectivePort = _discoveredPhone!.gatewayPort;
    } else {
      setState(() => _error =
          'Phone IP not found.\nEnable Gateway on phone and wait 2 seconds for auto-detect,\nor tap "Enter IP manually" and type the IP shown on your phone.');
      return;
    }

    final target = direct ??
        PairingCode(
          code: _enteredCode,
          gatewayIp: effectiveIp,
          gatewayPort: effectivePort,
          deviceName: 'Phone Gateway',
          createdAt: DateTime.now(),
        );

    setState(() {
      _connecting = true;
      _error = null;
    });

    final success =
        await ref.read(tvTunnelProvider.notifier).connectToGateway(target);

    if (mounted) {
      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        setState(() {
          _connecting = false;
          _error =
              'Could not connect to ${target.gatewayIp}:${target.gatewayPort}.\n'
              'Make sure:\n'
              '• Phone Gateway switch is ON\n'
              '• TV Wi-Fi is connected to phone network (DIRECT-...)\n'
              '• The IP shown below matches Gateway Address on phone app';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TvColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Status + Code display + IP display ─────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pin_rounded, color: colors.accent, size: 36),
                      const Gap(14),
                      Text(
                        'Connect to Phone Gateway',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: 30,
                              color: colors.accent,
                            ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Look at your phone\'s DirectNet app screen for the code and IP.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 17),
                  ),
                  const Gap(20),

                  // ── Auto-Discovery Banner ─────────────────────────────
                  if (_discoveredPhone != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cell_tower_rounded, color: colors.success, size: 28),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📡 Phone Gateway Found Automatically!',
                                  style: TextStyle(
                                    color: colors.success,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  'IP: ${_discoveredPhone!.gatewayIp}:${_discoveredPhone!.gatewayPort}  •  Code: ${_discoveredPhone!.formattedCode}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(12),
                          _TvKeypadButton(
                            label: 'Connect Now',
                            icon: Icons.check_circle_rounded,
                            autofocus: true,
                            isAction: true,
                            colors: colors,
                            onPressed: _connecting
                                ? null
                                : () => _submitConnect(_discoveredPhone),
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),
                  ] else ...[
                    // No beacon yet — show waiting hint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.warning,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              'Searching for phone... Enable Gateway on phone app first. '
                              'If not found in 5 seconds, tap "Enter IP" and type manually.',
                              style: TextStyle(color: colors.warning, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),
                  ],

                  // ── 6-Digit Code Display ──────────────────────────────
                  _SectionLabel(
                    label: 'STEP 1 — Enter 6-digit code from phone app',
                    isActive: _keypadMode == _KeypadMode.code,
                    colors: colors,
                    onTap: () => setState(() => _keypadMode = _KeypadMode.code),
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      for (int i = 0; i < 6; i++) ...[
                        if (i == 3) const Gap(16),
                        _TvDigitSlot(
                          digit: i < _enteredCode.length ? _enteredCode[i] : null,
                          isCurrent: i == _enteredCode.length &&
                              _keypadMode == _KeypadMode.code,
                          colors: colors,
                        ),
                        if (i != 2 && i != 5) const Gap(10),
                      ],
                    ],
                  ),
                  const Gap(20),

                  // ── IP Address Entry ──────────────────────────────────
                  _SectionLabel(
                    label: 'STEP 2 — Enter Gateway IP from phone app (auto-filled if found)',
                    isActive: _keypadMode == _KeypadMode.ip,
                    colors: colors,
                    onTap: () => setState(() => _keypadMode = _KeypadMode.ip),
                  ),
                  const Gap(10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _keypadMode == _KeypadMode.ip
                                ? colors.accent.withValues(alpha: 0.08)
                                : colors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _keypadMode == _KeypadMode.ip
                                  ? colors.accent
                                  : colors.border,
                              width: _keypadMode == _KeypadMode.ip ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _enteredIp.isEmpty
                                    ? '— tap "Enter IP" button →'
                                    : _enteredIp,
                                style: TextStyle(
                                  color: _enteredIp.isEmpty
                                      ? colors.textSecondary
                                      : colors.accent,
                                  fontSize: 20,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_keypadMode == _KeypadMode.ip) ...[
                                const Gap(4),
                                Container(
                                  width: 2,
                                  height: 24,
                                  color: colors.accent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Gap(12),
                      _TvKeypadButton(
                        label: _keypadMode == _KeypadMode.ip
                            ? 'Done (use code)'
                            : 'Enter IP manually',
                        icon: _keypadMode == _KeypadMode.ip
                            ? Icons.pin_rounded
                            : Icons.edit_rounded,
                        colors: colors,
                        onPressed: () => setState(() {
                          _keypadMode = _keypadMode == _KeypadMode.ip
                              ? _KeypadMode.code
                              : _KeypadMode.ip;
                        }),
                      ),
                      if (_enteredIp.isNotEmpty) ...[
                        const Gap(8),
                        _TvKeypadButton(
                          icon: Icons.clear_rounded,
                          label: 'Clear IP',
                          colors: colors,
                          onPressed: _onIpClear,
                        ),
                      ],
                    ],
                  ),
                  const Gap(6),
                  Text(
                    'Standard Wi-Fi Direct: 192.168.49.1:10808 (Hotspot OFF). Or check IP on phone.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),

                  // ── Error ─────────────────────────────────────────────
                  if (_error != null) ...[
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),
                  _TvKeypadButton(
                    label: 'Back to Home',
                    icon: Icons.arrow_back_rounded,
                    colors: colors,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Gap(48),

            // ── RIGHT: D-Pad Keypad (switches between code/IP mode) ──────
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mode indicator
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _keypadMode == _KeypadMode.code
                            ? '🔢 Typing: Pairing Code'
                            : '🌐 Typing: Phone IP Address',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Gap(10),

                    // Number rows 1-9
                    _buildKeypadRow(['1', '2', '3'], colors),
                    const Gap(10),
                    _buildKeypadRow(['4', '5', '6'], colors),
                    const Gap(10),
                    _buildKeypadRow(['7', '8', '9'], colors),
                    const Gap(10),

                    // Bottom row: Clear | 0 | Backspace
                    // For IP mode: also show '.' button
                    if (_keypadMode == _KeypadMode.ip) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _TvKeypadButton(
                              label: 'C',
                              colors: colors,
                              onPressed: _onIpClear,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _TvKeypadButton(
                              label: '0',
                              colors: colors,
                              onPressed: () => _onIpChar('0'),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _TvKeypadButton(
                              label: '.',
                              colors: colors,
                              onPressed: () {
                                // Only add dot if doesn't already end with dot
                                // and we have fewer than 3 dots
                                final dots =
                                    '.'.allMatches(_enteredIp).length;
                                if (!_enteredIp.endsWith('.') && dots < 3) {
                                  _onIpChar('.');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const Gap(10),
                      Row(
                        children: [
                          Expanded(
                            child: _TvKeypadButton(
                              icon: Icons.backspace_outlined,
                              colors: colors,
                              onPressed: _onIpBackspace,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            flex: 2,
                            child: _TvKeypadButton(
                              label: 'Done (use code keypad)',
                              isAction: false,
                              colors: colors,
                              onPressed: () =>
                                  setState(() => _keypadMode = _KeypadMode.code),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _TvKeypadButton(
                              label: 'C',
                              colors: colors,
                              onPressed: _onCodeClear,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _TvKeypadButton(
                              label: '0',
                              colors: colors,
                              onPressed: () => _onDigitPressedForCode('0'),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: _TvKeypadButton(
                              icon: Icons.backspace_outlined,
                              colors: colors,
                              onPressed: _onCodeBackspace,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const Gap(14),
                    _TvKeypadButton(
                      label: 'Connect to Phone',
                      icon: Icons.wifi_tethering_rounded,
                      isAction: true,
                      autofocus: _discoveredPhone == null,
                      colors: colors,
                      onPressed:
                          (_connecting || _enteredCode.length < 6)
                              ? null
                              : _submitConnect,
                    ),
                    if (_connecting) ...[
                      const Gap(10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.accent),
                          ),
                          const Gap(10),
                          Text('Connecting...',
                              style: TextStyle(
                                  color: colors.accent, fontSize: 15)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, TvColors colors) {
    final isIpMode = _keypadMode == _KeypadMode.ip;
    return Row(
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          Expanded(
            child: _TvKeypadButton(
              label: digits[i],
              colors: colors,
              onPressed: () => isIpMode
                  ? _onIpChar(digits[i])
                  : _onDigitPressedForCode(digits[i]),
            ),
          ),
          if (i != digits.length - 1) const Gap(10),
        ],
      ],
    );
  }
}

// ── Section label with tap-to-activate ───────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isActive;
  final TvColors colors;
  final VoidCallback onTap;

  const _SectionLabel({
    required this.label,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? colors.accent : colors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Digit Slot ────────────────────────────────────────────────────────────────

class _TvDigitSlot extends StatelessWidget {
  final String? digit;
  final bool isCurrent;
  final TvColors colors;

  const _TvDigitSlot({
    required this.digit,
    required this.isCurrent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? colors.accent
              : (digit != null
                  ? colors.accent.withValues(alpha: 0.5)
                  : colors.border),
          width: isCurrent ? 2.5 : 1.5,
        ),
      ),
      child: Text(
        digit ?? (isCurrent ? '_' : '·'),
        style: TextStyle(
          color: digit != null ? colors.accent : colors.textSecondary,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Remote D-pad focusable button with high-contrast TV selection glow
class _TvKeypadButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isAction;
  final bool autofocus;
  final TvColors colors;

  const _TvKeypadButton({
    this.label,
    this.icon,
    this.onPressed,
    this.isAction = false,
    this.autofocus = false,
    required this.colors,
  });

  @override
  State<_TvKeypadButton> createState() => _TvKeypadButtonState();
}

class _TvKeypadButtonState extends State<_TvKeypadButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final bg = widget.isAction ? widget.colors.accent : widget.colors.surface;
    final fg = widget.isAction ? Colors.black : Colors.white;

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
          duration: const Duration(milliseconds: 120),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _focused
                ? (widget.isAction ? Colors.white : widget.colors.accent)
                : (isEnabled ? bg : bg.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? Colors.white : widget.colors.border,
              width: _focused ? 2.5 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.colors.accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 20,
                  color: _focused ? Colors.black : fg,
                ),
                if (widget.label != null) const Gap(8),
              ],
              if (widget.label != null)
                Flexible(
                  child: Text(
                    widget.label!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _focused ? Colors.black : fg,
                      fontSize: widget.isAction ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
