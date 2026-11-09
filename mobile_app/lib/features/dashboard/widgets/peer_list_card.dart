import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shared/shared.dart';
import '../../../core/theme/app_theme.dart';

class PeerListCard extends StatelessWidget {
  final List<PeerInfo> peers;
  final void Function(String peerId) onRemovePeer;

  const PeerListCard({
    super.key,
    required this.peers,
    required this.onRemovePeer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DirectNetColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.tv_rounded, color: colors.accent, size: 20),
                const Gap(10),
                Text('Connected Devices', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${peers.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: colors.textSecondary),
                  const Gap(8),
                  Text(
                    'No TVs paired yet. Tap + Add TV',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            ...peers.asMap().entries.map((entry) {
              final i = entry.key;
              final peer = entry.value;
              return Column(
                children: [
                  if (i > 0) Divider(color: colors.border, height: 1, indent: 20),
                  _PeerTile(peer: peer, onRemove: () => _confirmRemove(context, peer)),
                ],
              );
            }),
          const Gap(4),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, PeerInfo peer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Device?'),
        content: Text('Remove "${peer.name}" from DirectNet? The TV will lose internet access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemovePeer(peer.id);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final PeerInfo peer;
  final VoidCallback onRemove;

  const _PeerTile({required this.peer, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = DirectNetColors.of(context);
    final isOnline = peer.isOnline;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (isOnline ? colors.success : colors.textSecondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isOnline ? colors.success : colors.border).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          Icons.tv_rounded,
          color: isOnline ? colors.success : colors.textSecondary,
          size: 22,
        ),
      ),
      title: Text(peer.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        '${peer.assignedIP}  •  ${isOnline ? "Online" : _lastSeen(peer.lastSeenAt)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isOnline ? colors.success : colors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: colors.textSecondary),
        onPressed: onRemove,
      ),
    );
  }

  String _lastSeen(DateTime? t) {
    if (t == null) return 'Never connected';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

