import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DirectNetColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(color: colors.accent),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Gateway'),
          _SettingsTile(
            icon: Icons.lock_rounded,
            title: 'WireGuard Port',
            subtitle: '51820 (UDP)',
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.dns_rounded,
            title: 'DNS Servers',
            subtitle: '1.1.1.1, 8.8.8.8',
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.network_cell_rounded,
            title: 'VPN Subnet',
            subtitle: '10.6.0.0/24',
            colors: colors,
          ),
          const Gap(24),
          const _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'DirectNet Version',
            subtitle: '1.0.0',
            colors: colors,
          ),
          _SettingsTile(
            icon: Icons.verified_user_rounded,
            title: 'Protocol',
            subtitle: 'WireGuard® (ChaCha20 + Poly1305)',
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final colors = DirectNetColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final DirectNetColors colors;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: colors.card,
        leading: Icon(icon, color: colors.accent, size: 22),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

