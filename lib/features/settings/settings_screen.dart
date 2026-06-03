import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/providers/betting_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final initial = user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          children: [
            // Profile card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF111A2E), Color(0x0800E676)],
                ),
                border: Border.all(color: const Color(0x0FFFFFFF)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B060)]),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(fontSize: 28, color: Colors.black, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.email ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(user?.id.substring(0, 8) ?? '', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: const Color(0xFF4A5568))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data management
            _sectionTitle('数据管理'),
            _menuItem(Icons.download, '导出 CSV', subtitle: '导出所有投注记录', iconColor: const Color(0xFF00E676), onTap: () => _exportCsv(context, ref)),
            _menuItem(Icons.folder, '数据备份', subtitle: '功能开发中', iconColor: const Color(0xFF448AFF)),

            const SizedBox(height: 16),

            // Preferences
            _sectionTitle('偏好设置'),
            _menuItem(Icons.palette, '深色模式', subtitle: '已启用', iconColor: const Color(0xFFFFAB00)),
            _menuItem(Icons.currency_yen, '默认货币', subtitle: 'CNY (¥)', iconColor: const Color(0xFF8A96B0)),

            const SizedBox(height: 16),

            // About
            _sectionTitle('关于'),
            _menuItem(Icons.info, '关于 LotteryAcct', subtitle: 'v1.0.0', iconColor: const Color(0xFF8A96B0)),
            _menuItem(Icons.chat, '意见反馈', iconColor: const Color(0xFF8A96B0)),

            const SizedBox(height: 16),

            // Logout
            _menuItem(Icons.logout, '退出登录', iconColor: const Color(0xFFFF3D57), titleColor: const Color(0xFFFF3D57), onTap: () async {
              await Supabase.instance.client.auth.signOut();
            }),

            const SizedBox(height: 20),
            Text('LotteryAcct v1.0.0', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: const Color(0xFF4A5568))),
            const Text('Built with Flutter + Supabase', style: TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4A5568), letterSpacing: 0.06)),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title, {
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          border: Border.all(color: const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: (iconColor ?? const Color(0xFF8A96B0)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: iconColor ?? const Color(0xFF8A96B0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: titleColor)),
                  if (subtitle != null)
                    Padding(padding: const EdgeInsets.only(top: 1), child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568)))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A5568), size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final records = await ref.read(bettingRecordsProvider.future);
      final rows = [
        ['日期', '比赛', '类别', '玩法', '赔率', '金额', '盈亏', '状态'],
        ...records.map((r) => [
              '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}',
              r.matchName ?? '',
              r.category.name,
              r.playType,
              r.odds.toString(),
              r.stake.toString(),
              r.resultAmount?.toString() ?? '',
              r.status.name,
            ]),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      await Share.share(csv, subject: 'LotteryAcct_投注记录.csv');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败'), backgroundColor: Color(0xFFFF3D57)),
        );
      }
    }
  }
}
