import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://qdlslssvkjkgikdjfcuk.supabase.co');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkbHNsc3N2a2prZ2lrZGpmY3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NTAzMDksImV4cCI6MjA5NjAyNjMwOX0.YayStJn-wEbOdcpFToCPQa10XYNzhDQjwUMCaz3KoFY');
  debugPrint('Supabase URL: $supabaseUrl');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await initializeDateFormatting('zh_CN');

  runApp(const ProviderScope(child: LotteryAcctApp()));
}
