import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/betting_record.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/providers/approval_provider.dart';
import '../../shared/widgets/loading_indicator.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(bettingRecordsProvider);
    final approvalMapAsync = ref.watch(pendingApprovalMapProvider);
    final approvalMap = approvalMapAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _filterChip(null, '全部', _filterStatus == null),
                const SizedBox(width: 8),
                _filterChip('pending', '待结算', _filterStatus == 'pending'),
                const SizedBox(width: 8),
                _filterChip('settled', '已结算', _filterStatus == 'settled'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Records list
          Expanded(
            child: recordsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('加载失败', style: TextStyle(color: Color(0xFFFF3D57)))),
              data: (records) {
                final filtered = _applyFilters(records);
                if (filtered.isEmpty) {
                  return const Center(child: Text('暂无记录', style: TextStyle(color: Color(0xFF4A5568))));
                }
                return RefreshIndicator(
                  color: const Color(0xFF00E676),
                  backgroundColor: const Color(0xFF111A2E),
                  onRefresh: () async => ref.invalidate(bettingRecordsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _HistoryItem(record: filtered[i], pendingApprovalOp: approvalMap[filtered[i].id]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<BettingRecord> _applyFilters(List<BettingRecord> records) {
    if (_filterStatus == 'settled') {
      return records.where((r) => r.status == BetStatus.won || r.status == BetStatus.lost).toList();
    } else if (_filterStatus == 'pending') {
      return records.where((r) => r.status == BetStatus.pending).toList();
    }
    return records;
  }

  Widget _filterChip(String? status, String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = active ? null : status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFF111A2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? const Color(0xFF00E676) : const Color(0xFF4A5568),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final BettingRecord record;
  final ApprovalOp? pendingApprovalOp;
  const _HistoryItem({required this.record, this.pendingApprovalOp});

  String get _statusLabel => switch (record.status) {
    BetStatus.awaitingApproval => '待审批',
    BetStatus.pending => '待结算',
    BetStatus.won => '已结算 · 赢',
    BetStatus.lost => '已结算 · 负',
    BetStatus.partial => '半结算',
    BetStatus.voided => '已退注',
  };

  Color get _statusColor => switch (record.status) {
    BetStatus.awaitingApproval => const Color(0xFF8A96B0),
    BetStatus.pending => const Color(0xFFFFAB00),
    BetStatus.won => const Color(0xFF00E676),
    BetStatus.lost => const Color(0xFFFF3D57),
    BetStatus.partial => const Color(0xFF448AFF),
    BetStatus.voided => const Color(0xFF4A5568),
  };

  @override
  Widget build(BuildContext context) {
    final isPositive = record.isPositive;
    final pnlColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57);
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          border: Border.all(color: const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚽ ${record.matchName ?? (record.betType == BetType.parlay ? '串关' : '--')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(record.createdAt)} · ${record.playType}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568)),
                      ),
                    ],
                  ),
                ),
                if (record.isSettled)
                  Text(
                    '${isPositive ? "+" : ""}¥${record.pnl.toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: pnlColor),
                  )
                else if (record.status == BetStatus.awaitingApproval)
                  const Text('待审批', style: TextStyle(fontSize: 14, color: Color(0xFF8A96B0)))
                else
                  const Text('待结算', style: TextStyle(fontSize: 14, color: Color(0xFFFFAB00))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (record.betType == BetType.parlay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB00).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('串关', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFFFAB00))),
                      ),
                    if (pendingApprovalOp != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A96B0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pendingApprovalOp == ApprovalOp.settle ? '结算审批中' : pendingApprovalOp == ApprovalOp.delete ? '删除审批中' : '审批中',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8A96B0)),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '@${record.odds} · ¥${record.stake.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFF4A5568)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1220),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DetailSheet(record: record, pendingApprovalOp: pendingApprovalOp),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class _DetailSheet extends ConsumerWidget {
  final BettingRecord record;
  final ApprovalOp? pendingApprovalOp;
  const _DetailSheet({required this.record, this.pendingApprovalOp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalMap = ref.watch(pendingApprovalMapProvider).valueOrNull ?? {};
    final op = pendingApprovalOp ?? approvalMap[record.id];
    final showSettle = record.status == BetStatus.pending && op != ApprovalOp.settle;
    final showDelete = op == null;
    final hasApproval = op != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: const BoxDecoration(color: Color(0xFF4A5568), borderRadius: BorderRadius.all(Radius.circular(2)))),
            const SizedBox(height: 16),
            Text(record.matchName ?? '串关', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _row('投注类型', record.betType == BetType.single ? '单关 · ${record.playType}' : '串关'),
            if (record.betSelection.isNotEmpty)
              _row('投注方向', record.betSelection, valueColor: const Color(0xFF00E676)),
            if (record.ticketImageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () => _showTicketImage(context, record.ticketImageUrl!),
                  child: Row(
                    children: [
                      const Text('查看原始票据', style: TextStyle(fontSize: 13, color: Color(0xFF8A96B0))),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 14, color: Color(0xFF00E676)),
                    ],
                  ),
                ),
              ),
            if (record.betType == BetType.parlay)
              Builder(builder: (_) {
                final legsAsync = ref.watch(betLegsProvider(record.id));
                return legsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                  data: (legs) {
                    if (legs.isEmpty) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('串关场次', '${legs.length} 场'),
                        ...legs.map((leg) => Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${leg.matchName} · ${leg.playType}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '@${leg.odds}',
                                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFF4A5568)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    );
                  },
                );
              }),
            _row('赔率', '@${record.odds}'),
            _row('投注金额', '¥${record.stake.toStringAsFixed(0)}'),
            _row('可赢金额', '¥${(record.stake * record.odds).toStringAsFixed(0)}'),
            _row(
              '结算状态',
              record.status == BetStatus.awaitingApproval
                  ? '待审批'
                  : record.isSettled
                      ? '已结算 · ${record.status == BetStatus.won ? '赢' : '负'}'
                      : '未结算',
            ),
            if (hasApproval)
              _row(
                '审批状态',
                op == ApprovalOp.settle ? '结算审批中' : op == ApprovalOp.delete ? '删除审批中' : '新增审批中',
                valueColor: const Color(0xFF8A96B0),
              ),
            if (record.isSettled)
              _row('盈亏', '${record.isPositive ? "+" : ""}¥${record.pnl.toStringAsFixed(0)}', valueColor: record.isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57)),
            _row('投注时间', '${record.createdAt.year}/${record.createdAt.month}/${record.createdAt.day} ${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 20),
            if (showSettle)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref.read(bettingRecordsProvider.notifier).settleRecord(record.id, record.stake * record.odds - record.stake, BetStatus.won);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('操作失败: $e'), backgroundColor: const Color(0xFFFF3D57)),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                      child: const Text('赢了', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref.read(bettingRecordsProvider.notifier).settleRecord(record.id, -record.stake, BetStatus.lost);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('操作失败: $e'), backgroundColor: const Color(0xFFFF3D57)),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D57)),
                      child: const Text('输了', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            if (showSettle)
              const SizedBox(height: 10),
            // pending or awaiting_approval: direct delete (no approval needed)
            if (showDelete && !record.isSettled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(bettingRecordsProvider.notifier).deleteRecord(record.id, skipApproval: true);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('操作失败: $e'), backgroundColor: const Color(0xFFFF3D57)),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3D57), side: const BorderSide(color: Color(0xFFFF3D57))),
                  child: const Text('删除记录'),
                ),
              ),
            // settled: delete needs approval
            if (showDelete && record.isSettled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(bettingRecordsProvider.notifier).deleteRecord(record.id);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('操作失败: $e'), backgroundColor: const Color(0xFFFF3D57)),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3D57), side: const BorderSide(color: Color(0xFFFF3D57))),
                  child: const Text('申请删除'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTicketImage(BuildContext context, String url) {
    Navigator.pop(context); // Close detail sheet
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(child: Text('图片加载失败', style: TextStyle(color: Colors.white54))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A96B0))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFFE8ECF4))),
        ],
      ),
    );
  }
}
