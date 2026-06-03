import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/betting/add_bet_screen.dart';
import 'features/history/history_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';

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

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  static const _pages = [
    DashboardScreen(),
    HistoryScreen(),
    AddBetScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xDD06090F),
        indicatorColor: const Color(0x1A00E676),
        height: 64,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: '首页'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: '记录'),
          NavigationDestination(icon: Icon(Icons.add_circle_rounded), label: '添加'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: '分析'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: '设置'),
        ],
      ),
    );
  }
}
