import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/providers/betting_provider.dart';

class PnlCard extends StatelessWidget {
  final PnlSummary? pnl;
  const PnlCard({super.key, required this.pnl});

  @override
  Widget build(BuildContext context) {
    if (pnl == null) return const SizedBox.shrink();

    final isPositive = pnl!.monthlyPnl >= 0;
    final pnlColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57);

    return Column(
      children: [
        // Main P&L card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                pnlColor.withValues(alpha: 0.08),
                pnlColor.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pnlColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '本月盈亏',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A96B0),
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${isPositive ? '+' : ''}¥${_formatNumber(pnl!.monthlyPnl)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: pnlColor,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Win rate + Bet count row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2E),
                  border: Border.all(color: const Color(0x0FFFFFFF)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('胜率', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8A96B0), letterSpacing: 0.06)),
                    const SizedBox(height: 6),
                    Text(
                      pnl!.winRate != null ? '${pnl!.winRate!.toStringAsFixed(1)}%' : '--',
                      style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF00E676), height: 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2E),
                  border: Border.all(color: const Color(0x0FFFFFFF)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('投注笔数', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8A96B0), letterSpacing: 0.06)),
                    const SizedBox(height: 6),
                    Text(
                      '${pnl!.totalBets}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, height: 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value.abs() >= 10000) return '${(value / 10000).toStringAsFixed(1)}w';
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.abs().toStringAsFixed(0);
  }
}
