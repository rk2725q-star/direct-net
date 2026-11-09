import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import 'package:shared/shared.dart';
import '../../../core/theme/app_theme.dart';

class BandwidthChartCard extends StatelessWidget {
  final List<PeerInfo> peers;
  const BandwidthChartCard({super.key, required this.peers});

  @override
  Widget build(BuildContext context) {
    final colors = DirectNetColors.of(context);
    // Placeholder bandwidth data — real data comes from WG stats polling
    final spots = List.generate(
      10,
      (i) => FlSpot(i.toDouble(), (i % 3 + 1) * 0.5 + (i * 0.3)),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.area_chart_rounded, color: colors.accent, size: 20),
              const Gap(10),
              Text('Bandwidth', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _StatBadge(label: '↑ 0.4 MB/s', color: colors.warning),
              const Gap(8),
              _StatBadge(label: '↓ 2.1 MB/s', color: colors.accent),
            ],
          ),
          const Gap(20),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colors.accent,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.accent.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

