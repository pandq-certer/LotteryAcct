import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/models/betting_record.dart';
import '../../shared/providers/approval_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/widgets/loading_indicator.dart';

class ApprovalScreen extends ConsumerWidget {
  const ApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final allAsync = ref.watch(allApprovalsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('审批', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(text: '待审批${pendingAsync.whenOrNull(data: (d) { final n = d.where((r) => r.requestedBy != currentUserId).length; return n > 0 ? ' ($n)' : ''; }) ?? ''}'),
              const Tab(text: '历史'),
            ],
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: const Color(0xFF4A5568),
            indicatorColor: const Color(0xFF00E676),
          ),
        ),
        body: TabBarView(
          children: [
            // Pending tab
            pendingAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('加载失败: $e', style: const TextStyle(color: Color(0xFFFF3D57)))),
              data: (requests) {
                final others = requests.where((r) => r.requestedBy != currentUserId).toList();
                final mine = requests.where((r) => r.requestedBy == currentUserId).toList();

                if (others.isEmpty && mine.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF4A5568)),
                        SizedBox(height: 12),
                        Text('暂无待审批请求', style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (others.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('需要你审批', style: TextStyle(fontSize: 13, color: Color(0xFF8A96B0), fontWeight: FontWeight.w600)),
                      ),
                      ...others.map((r) => _ApprovalCard(request: r, canResolve: true)),
                      const SizedBox(height: 20),
                    ],
                    if (mine.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('等待对方审批', style: TextStyle(fontSize: 13, color: Color(0xFF8A96B0), fontWeight: FontWeight.w600)),
                      ),
                      ...mine.map((r) => _ApprovalCard(request: r, canResolve: false)),
                    ],
                  ],
                );
              },
            ),

            // History tab
            allAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('加载失败', style: const TextStyle(color: Color(0xFFFF3D57)))),
              data: (requests) {
                final resolved = requests.where((r) => r.status != ApprovalStatus.pending).toList();
                if (resolved.isEmpty) {
                  return const Center(
                    child: Text('暂无审批记录', style: TextStyle(color: Color(0xFF4A5568), fontSize: 14)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: resolved.length,
                  itemBuilder: (_, i) => _ApprovalCard(request: resolved[i], canResolve: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  final ApprovalRequest request;
  final bool canResolve;

  const _ApprovalCard({required this.request, required this.canResolve});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opColor = {
      ApprovalOp.create: const Color(0xFF00E676),
      ApprovalOp.settle: const Color(0xFFFFB300),
      ApprovalOp.delete: const Color(0xFFFF3D57),
    };
    final statusColor = {
      ApprovalStatus.pending: const Color(0xFFFFB300),
      ApprovalStatus.approved: const Color(0xFF00E676),
      ApprovalStatus.rejected: const Color(0xFFFF3D57),
    };
    final statusLabel = {
      ApprovalStatus.pending: '待审批',
      ApprovalStatus.approved: '已同意',
      ApprovalStatus.rejected: '已拒绝',
    };

    // Try payload first, fall back to record if missing
    final hasPayloadDetails = (request.payload['match_name'] as String?) != null
        || (request.payload['bet_type'] as String?) != null;
    final recordAsync = (request.recordId != null && !hasPayloadDetails)
        ? ref.watch(bettingRecordByIdProvider(request.recordId!))
        : null;

    return recordAsync != null
        ? recordAsync.when(
            loading: () => _buildCard(context, ref, opColor, statusColor, statusLabel, null),
            error: (_, _) => _buildCard(context, ref, opColor, statusColor, statusLabel, null),
            data: (record) => _buildCard(context, ref, opColor, statusColor, statusLabel, record),
          )
        : _buildCard(context, ref, opColor, statusColor, statusLabel, null);
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    Map<ApprovalOp, Color> opColor,
    Map<ApprovalStatus, Color> statusColor,
    Map<ApprovalStatus, String> statusLabel,
    BettingRecord? record,
  ) {
    // Merge payload + record fallback
    final p = request.payload;
    String? rawMatchName = p['match_name'] as String?;
    String? betType = p['bet_type'] as String?;
    String? playType = p['play_type'] as String?;
    num? stake = p['stake'] as num?;
    num? odds = p['odds'] as num?;
    final resultAmount = p['result_amount'] as num?;
    final settleStatus = p['status'] as String?;

    if (record != null) {
      rawMatchName ??= record.matchName;
      betType ??= record.betType.name;
      playType ??= record.playType;
      stake ??= record.stake;
      odds ??= record.odds;
    }

    final betTypeLabel = betType == 'parlay' ? '串关' : betType == 'single' ? '单关' : null;
    final title = (rawMatchName != null && rawMatchName.isNotEmpty)
        ? rawMatchName
        : (betTypeLabel ?? request.operationLabel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: opColor[request.operation]?.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.operationLabel,
                  style: TextStyle(
                    color: opColor[request.operation],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (request.status != ApprovalStatus.pending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor[request.status]?.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel[request.status] ?? '',
                    style: TextStyle(color: statusColor[request.status], fontSize: 11),
                  ),
                ),
              Text(
                DateFormat('MM/dd HH:mm').format(request.createdAt),
                style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE8ECF4))),
          const SizedBox(height: 4),
          Row(
            children: [
              if (betTypeLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(betTypeLabel, style: const TextStyle(fontSize: 11, color: Color(0xFFFFAB00), fontWeight: FontWeight.w600)),
                ),
              if (playType != null && playType.isNotEmpty)
                Text(playType, style: const TextStyle(color: Color(0xFF8A96B0), fontSize: 13)),
              const Spacer(),
              if (request.operation == ApprovalOp.settle && settleStatus != null)
                Text(
                  settleStatus == 'won' ? '结算: 赢' : '结算: 输',
                  style: TextStyle(
                    color: settleStatus == 'won' ? const Color(0xFF00E676) : const Color(0xFFFF3D57),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (stake != null)
                Text('金额: ¥${stake.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF8A96B0), fontSize: 13)),
              if (odds != null) ...[
                const SizedBox(width: 16),
                Text('赔率: ${odds.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF8A96B0), fontSize: 13)),
              ],
              if (request.operation == ApprovalOp.settle && resultAmount != null && resultAmount != 0) ...[
                const SizedBox(width: 16),
                Text(
                  '盈亏: ¥${resultAmount > 0 ? '+' : ''}${resultAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: resultAmount > 0 ? const Color(0xFF00E676) : const Color(0xFFFF3D57),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (canResolve) ...[
            const SizedBox(height: 12),
            Builder(builder: (btnCtx) {
              Future<void> doResolve(bool approve) async {
                try {
                  await ref.read(approvalNotifierProvider.notifier).resolve(request.id, approve);
                  if (btnCtx.mounted) {
                    ScaffoldMessenger.of(btnCtx).showSnackBar(SnackBar(
                      content: Text(approve ? '已同意' : '已拒绝'),
                      backgroundColor: approve ? const Color(0xFF00E676) : const Color(0xFFFF3D57),
                      duration: const Duration(seconds: 1),
                    ));
                  }
                } catch (e) {
                  if (btnCtx.mounted) {
                    ScaffoldMessenger.of(btnCtx).showSnackBar(SnackBar(
                      content: Text('操作失败: $e'),
                      backgroundColor: const Color(0xFFFF3D57),
                    ));
                  }
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => doResolve(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3D57),
                        side: const BorderSide(color: Color(0xFFFF3D57)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('拒绝'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => doResolve(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('同意', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
