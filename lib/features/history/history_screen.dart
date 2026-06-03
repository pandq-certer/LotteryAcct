import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/betting_record.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/widgets/loading_indicator.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _filterCategory;
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(bettingRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _filterChip(null, '全部', _filterCategory == null && _filterStatus == null),
                _filterChip('cat', '足球', _filterCategory == 'football'),
                _filterChip('cat', '篮球', _filterCategory == 'basketball'),
                _filterChip('cat', '网球', _filterCategory == 'tennis'),
                _filterChip('status', '已结算', _filterStatus == 'settled'),
                _filterChip('status', '未结算', _filterStatus == 'pending'),
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
                    itemBuilder: (_, i) => _HistoryItem(record: filtered[i]),
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
    var result = records;
    if (_filterCategory != null) {
      final cat = BetCategory.values.firstWhere((c) => c.name == _filterCategory);
      result = result.where((r) => r.category == cat).toList();
    }
    if (_filterStatus == 'settled') {
      result = result.where((r) => r.status == BetStatus.won || r.status == BetStatus.lost).toList();
    } else if (_filterStatus == 'pending') {
      result = result.where((r) => r.status == BetStatus.pending).toList();
    }
    return result;
  }

  Widget _filterChip(String? type, String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == null) {
            _filterCategory = null;
            _filterStatus = null;
          } else if (type == 'cat') {
            _filterCategory = active ? null : {
              '足球': 'football', '篮球': 'basketball', '网球': 'tennis',
            }[label];
            _filterStatus = null;
          } else {
            _filterStatus = active ? null : (label == '已结算' ? 'settled' : 'pending');
            _filterCategory = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E676).withValues(alpha: 0.1) : const Color(0xFF111A2E),
          border: Border.all(color: active ? const Color(0xFF00E676) : const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? const Color(0xFF00E676) : const Color(0xFF8A96B0))),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final BettingRecord record;
  const _HistoryItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final isPositive = record.isPositive;
    final pnlColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57);
    final icon = record.category == BetCategory.football ? '⚽' : record.category == BetCategory.basketball ? '🏀' : record.category == BetCategory.tennis ? '🎾' : '🎯';

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
                        '$icon ${record.matchName ?? (record.betType == BetType.parlay ? '串关 × N' : '--')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(record.createdAt)} · ${_catLabel(record.category)} · ${record.playType}',
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
                        color: (record.isSettled ? const Color(0xFF00E676) : const Color(0xFFFFAB00)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        record.isSettled ? '已结算' : '未结算',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: record.isSettled ? const Color(0xFF00E676) : const Color(0xFFFFAB00)),
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
      backgroundColor: const Color(0xFF0C1220),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DetailSheet(record: record),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  String _catLabel(BetCategory c) => switch (c) { BetCategory.football => '足球', BetCategory.basketball => '篮球', BetCategory.tennis => '网球', BetCategory.other => '其他' };
}

class _DetailSheet extends ConsumerWidget {
  final BettingRecord record;
  const _DetailSheet({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: const BoxDecoration(color: Color(0xFF4A5568), borderRadius: BorderRadius.all(Radius.circular(2)))),
          const SizedBox(height: 16),
          Text(record.matchName ?? '串关', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _row('投注类型', record.betType == BetType.single ? '单关 · ${record.playType}' : '串关'),
          _row('赔率', '@${record.odds}'),
          _row('投注金额', '¥${record.stake.toStringAsFixed(0)}'),
          _row('可赢金额', '¥${(record.stake * record.odds).toStringAsFixed(0)}'),
          _row('结算状态', record.isSettled ? '已结算 · ${record.status == BetStatus.won ? '赢' : '负'}' : '未结算'),
          if (record.isSettled)
            _row('盈亏', '${record.isPositive ? "+" : ""}¥${record.pnl.toStringAsFixed(0)}', valueColor: record.isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3D57)),
          _row('投注时间', '${record.createdAt.year}/${record.createdAt.month}/${record.createdAt.day} ${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}'),
          const SizedBox(height: 20),
          if (record.status == BetStatus.pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(bettingRecordsProvider.notifier).settleRecord(record.id, record.stake * record.odds - record.stake, BetStatus.won);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                    child: const Text('赢了', style: TextStyle(color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(bettingRecordsProvider.notifier).settleRecord(record.id, -record.stake, BetStatus.lost);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D57)),
                    child: const Text('输了', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          if (record.status != BetStatus.pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(bettingRecordsProvider.notifier).deleteRecord(record.id);
                  if (context.mounted) Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF3D57), side: const BorderSide(color: Color(0xFFFF3D57))),
                child: const Text('删除记录'),
              ),
            ),
        ],
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
