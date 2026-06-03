import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/betting_record.dart';

class RecentRecords extends StatelessWidget {
  final List<BettingRecord> records;
  const RecentRecords({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          border: Border.all(color: const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('暂无投注记录', style: TextStyle(color: Color(0xFF4A5568), fontSize: 13))),
      );
    }

    return Column(
      children: records.map((r) => _RecordItem(record: r)).toList(),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final BettingRecord record;
  const _RecordItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final isPositive = record.isPositive;
    final pnlColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57);
    final icon = record.category == BetCategory.football
        ? '⚽'
        : record.category == BetCategory.basketball
            ? '🏀'
            : record.category == BetCategory.tennis
                ? '🎾'
                : '🎯';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.matchName ?? (record.betType == BetType.parlay ? '串关' : '--'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _StatusChip(status: record.status),
                    const SizedBox(width: 4),
                    Text(
                      '${_catLabel(record.category)} · ${record.playType}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // P&L
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (record.isSettled)
                Text(
                  '${isPositive ? '+' : ''}¥${record.pnl.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: pnlColor),
                )
              else
                const Text('待结算', style: TextStyle(fontSize: 12, color: Color(0xFFFFAB00))),
              const SizedBox(height: 2),
              Text('@${record.odds}', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: const Color(0xFF4A5568))),
            ],
          ),
        ],
      ),
    );
  }

  String _catLabel(BetCategory c) {
    switch (c) {
      case BetCategory.football: return '足球';
      case BetCategory.basketball: return '篮球';
      case BetCategory.tennis: return '网球';
      case BetCategory.other: return '其他';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final BetStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BetStatus.won => ('赢', Color(0xFF00E676)),
      BetStatus.lost => ('负', Color(0xFFFF3D57)),
      BetStatus.pending => ('待', Color(0xFFFFAB00)),
      BetStatus.partial => ('半', Color(0xFF448AFF)),
      BetStatus.voided => ('退', Color(0xFF4A5568)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
