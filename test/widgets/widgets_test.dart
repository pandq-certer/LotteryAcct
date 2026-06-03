import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/widgets/loading_indicator.dart';
import 'package:lottery_acct/shared/widgets/error_banner.dart';
import 'package:lottery_acct/features/dashboard/widgets/pnl_card.dart';
import 'package:lottery_acct/shared/providers/betting_provider.dart';

void main() {
  group('LoadingIndicator', () {
    testWidgets('renders without message', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingIndicator())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with message', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingIndicator(message: '加载中'))));
      expect(find.text('加载中'), findsOneWidget);
    });
  });

  group('ErrorBanner', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ErrorBanner(message: '出错了'))));
      expect(find.text('出错了'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ErrorBanner(message: '错误', onRetry: () => retryCalled = true)),
      ));
      await tester.tap(find.text('重试'));
      expect(retryCalled, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ErrorBanner(message: '错误'))));
      expect(find.text('重试'), findsNothing);
    });
  });

  group('PnlCard', () {
    testWidgets('renders monthly P&L value', (tester) async {
      const pnl = PnlSummary(
        totalBets: 10, wins: 6, settledBets: 8,
        totalPnl: 1500, monthlyPnl: 800, totalStake: 5000,
        winRate: 75.0,
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PnlCard(pnl: pnl))));
      expect(find.textContaining('800'), findsWidgets);
    });

    testWidgets('renders zero P&L', (tester) async {
      const pnl = PnlSummary(
        totalBets: 0, wins: 0, settledBets: 0,
        totalPnl: 0, monthlyPnl: 0, totalStake: 0,
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PnlCard(pnl: pnl))));
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('renders null PnlSummary as empty', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PnlCard(pnl: null))));
      expect(find.byType(PnlCard), findsOneWidget);
    });

    testWidgets('shows win rate percentage', (tester) async {
      const pnl = PnlSummary(
        totalBets: 20, wins: 14, settledBets: 18,
        totalPnl: 2000, monthlyPnl: 1000, totalStake: 8000,
        winRate: 77.8,
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PnlCard(pnl: pnl))));
      expect(find.textContaining('77.8%'), findsOneWidget);
    });

    testWidgets('shows total bet count', (tester) async {
      const pnl = PnlSummary(
        totalBets: 42, wins: 28, settledBets: 38,
        totalPnl: 2000, monthlyPnl: 1000, totalStake: 8000,
        winRate: 73.7,
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PnlCard(pnl: pnl))));
      expect(find.textContaining('42'), findsOneWidget);
    });
  });
}
