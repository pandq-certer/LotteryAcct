import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/betting_record.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/widgets/loading_indicator.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(bettingRecordsProvider);
    final pnlAsync = ref.watch(pnlSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据分析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          children: [
            // Quick stats
            pnlAsync.when(
              loading: () => const SizedBox(height: 80, child: LoadingIndicator()),
              error: (_, __) => const SizedBox(),
              data: (pnl) => _buildQuickStats(pnl),
            ),
            const SizedBox(height: 16),

            // Category distribution
            recordsAsync.when(
              loading: () => const SizedBox(height: 200, child: LoadingIndicator()),
              error: (_, __) => const SizedBox(),
              data: (records) => _buildCategoryChart(records),
            ),
            const SizedBox(height: 14),

            // Odds range win rate
            recordsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => _buildOddsRangeChart(records),
            ),
            const SizedBox(height: 14),

            // Heatmap
            recordsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) => _buildHeatmap(records),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(PnlSummary? pnl) {
    if (pnl == null) return const SizedBox();
    return Row(
      children: [
        Expanded(child: _statCard('+¥${_fmt(pnl.totalPnl)}', '总盈利', pnl.totalPnl >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF3D57))),
        const SizedBox(width: 8),
        Expanded(child: _statCard(pnl.winRate != null ? '${pnl.winRate!.toStringAsFixed(1)}%' : '--', '总胜率')),
        const SizedBox(width: 8),
        Expanded(child: _statCard(_avgOdds(pnl), '平均赔率')),
      ],
    );
  }

  Widget _statCard(String value, String label, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: color ?? const Color(0xFFE8ECF4))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(List<BettingRecord> records) {
    final counts = <BetCategory, int>{};
    for (final r in records) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox();

    final items = [
      (BetCategory.football, '足球', const Color(0xFF00E676)),
      (BetCategory.basketball, '篮球', const Color(0xFFFFAB00)),
      (BetCategory.tennis, '网球', const Color(0xFF448AFF)),
      (BetCategory.other, '其他', const Color(0xFFFF3D57)),
    ];

    final total = counts.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('投注分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(
                  PieChartData(
                    sections: items.map((item) {
                      final count = counts[item.$1] ?? 0;
                      if (count == 0) return null;
                      return PieChartSectionData(
                        value: count.toDouble(),
                        color: item.$3,
                        radius: 14,
                        title: '',
                        showTitle: false,
                      );
                    }).whereType<PieChartSectionData>().toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: items.map((item) {
                    final count = counts[item.$1] ?? 0;
                    final pct = total > 0 ? (count * 100 / total).round() : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 12, color: Color(0xFF8A96B0)))),
                          Text('$pct%', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOddsRangeChart(List<BettingRecord> records) {
    final settled = records.where((r) => r.status == BetStatus.won || r.status == BetStatus.lost).toList();
    if (settled.isEmpty) return const SizedBox();

    final ranges = [
      ('1.0-1.5', 1.0, 1.5),
      ('1.5-2.0', 1.5, 2.0),
      ('2.0-2.5', 2.0, 2.5),
      ('2.5-3.0', 2.5, 3.0),
      ('3.0+', 3.0, 999.0),
    ];

    final data = ranges.map((r) {
      final inRange = settled.where((b) => b.odds >= r.$2 && b.odds < r.$3);
      final wins = inRange.where((b) => b.status == BetStatus.won).length;
      final total = inRange.length;
      final rate = total > 0 ? wins / total : 0.0;
      return (r.$1, rate, total);
    }).toList();

    // Chart data ready

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('赔率区间胜率', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barGroups: data.asMap().entries.map((e) {
                  final color = e.value.$2 >= 0.6
                      ? const Color(0xFF00E676)
                      : e.value.$2 >= 0.4
                          ? const Color(0xFFFFAB00)
                          : const Color(0xFFFF3D57);
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(toY: e.value.$2, color: color, width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(data[idx].$1, style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF4A5568))),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A2540),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = data[groupIndex];
                      return BarTooltipItem(
                        '${(d.$2 * 100).toStringAsFixed(0)}% (${d.$3}注)',
                        GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(List<BettingRecord> records) {
    final settled = records.where((r) => r.status == BetStatus.won || r.status == BetStatus.lost).toList();
    if (settled.isEmpty) return const SizedBox();

    final cats = [BetCategory.football, BetCategory.basketball, BetCategory.tennis];
    final plays = ['独赢', '让球', '大小分', '串关'];
    final catLabels = {BetCategory.football: '⚽', BetCategory.basketball: '🏀', BetCategory.tennis: '🎾'};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('策略热力图', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Text('本月', style: TextStyle(fontSize: 11, color: Color(0xFF00E676))),
            ],
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              const SizedBox(width: 28),
              ...plays.map((p) => Expanded(child: Center(child: Text(p, style: const TextStyle(fontSize: 9, color: Color(0xFF4A5568)))))),
            ],
          ),
          const SizedBox(height: 4),
          // Rows
          ...cats.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text(catLabels[cat] ?? '', style: const TextStyle(fontSize: 12))),
                  ...plays.map((play) {
                    final matching = settled.where((r) {
                      if (play == '串关') return r.betType == BetType.parlay && r.category == cat;
                      return r.playType == play && r.category == cat;
                    }).toList();
                    final wins = matching.where((r) => r.status == BetStatus.won).length;
                    final rate = matching.isNotEmpty ? wins / matching.length : -1.0;
                    return Expanded(
                      child: Container(
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _heatColor(rate),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            rate < 0 ? '--' : '${(rate * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.spaceGrotesk(fontSize: 9, color: rate >= 0 ? const Color(0xFFE8ECF4) : const Color(0xFF4A5568)),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          // Legend
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('低', style: TextStyle(fontSize: 9, color: Color(0xFF4A5568))),
              const SizedBox(width: 4),
              ...[0.15, 0.3, 0.5, 0.8].map((a) => Container(width: 16, height: 8, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: Color(0xFF00E676).withValues(alpha: a), borderRadius: BorderRadius.circular(2)))),
              const Text('高', style: TextStyle(fontSize: 9, color: Color(0xFF4A5568))),
            ],
          ),
        ],
      ),
    );
  }

  Color _heatColor(double rate) {
    if (rate < 0) return const Color(0x08FFFFFF);
    if (rate >= 0.7) return const Color(0xFF00E676).withValues(alpha: 0.5);
    if (rate >= 0.5) return const Color(0xFF00E676).withValues(alpha: 0.3);
    if (rate >= 0.3) return const Color(0xFFFFAB00).withValues(alpha: 0.25);
    return const Color(0xFFFF3D57).withValues(alpha: 0.25);
  }

  String _fmt(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.abs().toStringAsFixed(0);
  }

  String _avgOdds(PnlSummary? pnl) {
    if (pnl == null || pnl.totalBets == 0) return '--';
    // Approximate from total stake / potential return not available directly
    return '--';
  }
}
