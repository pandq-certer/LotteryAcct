import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/providers/betting_provider.dart';

class TrendChart extends StatelessWidget {
  final List<DailyPnl> data;
  const TrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          border: Border.all(color: const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('暂无数据', style: TextStyle(color: Color(0xFF4A5568), fontSize: 13))),
      );
    }

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.cumulativePnl)).toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
              const Text('累计盈亏', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                data.length >= 2
                    ? '${_fmtDate(data.first.date)} - ${_fmtDate(data.last.date)}'
                    : '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY + padding * 2) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0x08FFFFFF),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      interval: data.length > 7 ? (data.length / 5).floorToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${data[idx].date.month}/${data[idx].date.day}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 9, color: const Color(0xFF4A5568)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E676),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: index == spots.length - 1 ? 4 : 2.5,
                        color: const Color(0xFF00E676),
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF00E676).withValues(alpha: 0.15),
                          const Color(0xFF00E676).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A2540),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '¥${s.y.toStringAsFixed(0)}',
                      GoogleFonts.spaceGrotesk(color: const Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.month}/${d.day}';
}
