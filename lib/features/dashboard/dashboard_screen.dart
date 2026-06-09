import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/providers/approval_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_banner.dart';
import '../settings/settings_screen.dart';
import 'widgets/pnl_card.dart';
import 'widgets/trend_chart.dart';
import 'widgets/recent_records.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pnlAsync = ref.watch(pnlSummaryProvider);
    final recordsAsync = ref.watch(bettingRecordsProvider);
    final dailyAsync = ref.watch(dailyPnlProvider);
    final approvalMap = ref.watch(pendingApprovalMapProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00B060)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text('♦', style: TextStyle(fontSize: 14, color: Colors.black)),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Lottery',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE8ECF4),
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: 'Acct',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00E676),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF8A96B0)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF8A96B0)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00E676),
        backgroundColor: const Color(0xFF111A2E),
        onRefresh: () async {
          ref.invalidate(pnlSummaryProvider);
          ref.invalidate(bettingRecordsProvider);
          ref.invalidate(dailyPnlProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Greeting
            Text(
              _greeting(user?.email ?? ''),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(DateTime.now()),
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A96B0)),
            ),
            const SizedBox(height: 20),

            // P&L Cards
            pnlAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorBanner(message: '加载失败', onRetry: () => ref.invalidate(pnlSummaryProvider)),
              data: (pnl) => PnlCard(pnl: pnl),
            ),
            const SizedBox(height: 20),

            // Trend Chart
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 3, height: 14, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF00E676), borderRadius: BorderRadius.all(Radius.circular(2))))),
                  SizedBox(width: 8),
                  Text('近7日趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF8A96B0), letterSpacing: 0.04)),
                ],
              ),
            ),
            dailyAsync.when(
              loading: () => const SizedBox(height: 160, child: LoadingIndicator()),
              error: (e, _) => ErrorBanner(message: '图表加载失败'),
              data: (data) => TrendChart(data: data),
            ),
            const SizedBox(height: 20),

            // Recent Records
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    SizedBox(width: 3, height: 14, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF00E676), borderRadius: BorderRadius.all(Radius.circular(2))))),
                    SizedBox(width: 8),
                    Text('最近投注', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF8A96B0), letterSpacing: 0.04)),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(tabIndexProvider.notifier).state = 1,
                  child: const Text('查看全部 ›', style: TextStyle(color: Color(0xFF00E676), fontSize: 12)),
                ),
              ],
            ),
            recordsAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorBanner(message: '记录加载失败'),
              data: (records) => RecentRecords(records: records.take(5).toList(), approvalMap: approvalMap),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(String email) {
    final hour = DateTime.now().hour;
    final period = hour < 12 ? '上午好' : hour < 18 ? '下午好' : '晚上好';
    return '$period 👋';
  }
}
