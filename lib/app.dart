import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      home: const _MainShell(),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    _PlaceholderPage(title: '首页', icon: Icons.dashboard_rounded),
    _PlaceholderPage(title: '记录', icon: Icons.history_rounded),
    _PlaceholderPage(title: '添加', icon: Icons.add_rounded),
    _PlaceholderPage(title: '分析', icon: Icons.analytics_rounded),
    _PlaceholderPage(title: '设置', icon: Icons.settings_rounded),
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

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LotteryAcct',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE8ECF4),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF00E676)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '即将实现',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
