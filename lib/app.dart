import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/betting/add_bet_screen.dart';
import 'features/history/history_screen.dart';
import 'features/approvals/approval_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'shared/providers/approval_provider.dart';
import 'shared/providers/auth_provider.dart';

final tabIndexProvider = StateProvider<int>((ref) => 0);

class LotteryAcctApp extends StatelessWidget {
  const LotteryAcctApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LotteryAcct',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFF06090F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFFFFAB00),
          error: Color(0xFFFF3D57),
          surface: Color(0xFF0C1220),
          onSurface: Color(0xFFE8ECF4),
        ),
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE8ECF4),
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE8ECF4),
          ),
          titleLarge: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.notoSansSc(fontSize: 16),
          bodyMedium: GoogleFonts.notoSansSc(fontSize: 14),
          bodySmall: GoogleFonts.notoSansSc(
            fontSize: 12,
            color: Color(0xFF8A96B0),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111A2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x0FFFFFFF), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0E1726),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x0FFFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x0FFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00E676)),
          ),
          hintStyle: TextStyle(color: const Color(0xFF4A5568)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.notoSansSc(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    return const _MainShell();
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _pages = [
    DashboardScreen(),
    HistoryScreen(),
    AddBetScreen(),
    ApprovalScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);
    final pendingAsync = ref.watch(pendingApprovalsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final pendingCount = pendingAsync.whenOrNull(
      data: (d) => d.where((r) => r.requestedBy != userId).length,
    ) ?? 0;

    return Scaffold(
      body: _pages[currentIndex],
      bottomNavigationBar: _buildBottomNav(pendingCount, currentIndex),
    );
  }

  Widget _buildBottomNav(int pendingCount, int currentIndex) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 64 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1221),
            border: Border(
              top: BorderSide(color: Color(0x15FFFFFF), width: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _navItem(0, Icons.dashboard_rounded, '首页', currentIndex),
                _navItem(1, Icons.history_rounded, '记录', currentIndex),
                const SizedBox(width: 56),
                _navItem(
                  3,
                  Icons.fact_check_rounded,
                  '审批',
                  currentIndex,
                  badgeCount: pendingCount,
                ),
                _navItem(4, Icons.analytics_rounded, '分析', currentIndex),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: -20,
          child: Center(
            child: GestureDetector(
              onTap: () => ref.read(tabIndexProvider.notifier).state = 2,
              child: _addFab(currentIndex),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label, int currentIndex,
      {int badgeCount = 0}) {
    final selected = currentIndex == index;
    final color =
        selected ? const Color(0xFF00E676) : const Color(0xFF5A6578);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(tabIndexProvider.notifier).state = index,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 24,
                child: badgeCount > 0
                    ? Badge(
                        label: Text('$badgeCount',
                            style: const TextStyle(fontSize: 10)),
                        child: Icon(icon, color: color, size: 22),
                      )
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: selected ? 16 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addFab(int currentIndex) {
    final selected = currentIndex == 2;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0x5900E676),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
        border: selected
            ? Border.all(color: Colors.white24, width: 2)
            : null,
      ),
      child: Icon(
        Icons.add_rounded,
        color: selected ? Colors.white : const Color(0xFF06090F),
        size: 30,
      ),
    );
  }
}
