import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/providers/betting_provider.dart';

void main() {
  group('PnlSummary', () {
    test('fromJson parses all fields', () {
      final json = {
        'total_bets': 87,
        'wins': 56,
        'settled_bets': 82,
        'total_pnl': 3280.50,
        'monthly_pnl': 1500.0,
        'total_stake': 25000.0,
        'win_rate': 68.3,
      };

      final pnl = PnlSummary.fromJson(json);

      expect(pnl.totalBets, 87);
      expect(pnl.wins, 56);
      expect(pnl.settledBets, 82);
      expect(pnl.totalPnl, 3280.50);
      expect(pnl.monthlyPnl, 1500.0);
      expect(pnl.totalStake, 25000.0);
      expect(pnl.winRate, 68.3);
    });

    test('fromJson handles null winRate', () {
      final json = {
        'total_bets': 0,
        'wins': 0,
        'settled_bets': 0,
        'total_pnl': 0.0,
        'monthly_pnl': 0.0,
        'total_stake': 0.0,
        'win_rate': null,
      };

      final pnl = PnlSummary.fromJson(json);
      expect(pnl.winRate, isNull);
    });

    test('default PnlSummary has zero values', () {
      const pnl = PnlSummary(
        totalBets: 0, wins: 0, settledBets: 0,
        totalPnl: 0, monthlyPnl: 0, totalStake: 0,
      );

      expect(pnl.totalBets, 0);
      expect(pnl.totalPnl, 0);
      expect(pnl.winRate, isNull);
    });
  });

  group('DailyPnl', () {
    test('fromJson parses all fields', () {
      final json = {
        'bet_date': '2026-06-01',
        'daily_pnl': 580.0,
        'cumulative_pnl': 2500.0,
      };

      final daily = DailyPnl.fromJson(json);

      expect(daily.date.year, 2026);
      expect(daily.date.month, 6);
      expect(daily.date.day, 1);
      expect(daily.dailyPnl, 580.0);
      expect(daily.cumulativePnl, 2500.0);
    });

    test('fromJson handles negative values', () {
      final json = {
        'bet_date': '2026-06-02',
        'daily_pnl': -320.0,
        'cumulative_pnl': 2180.0,
      };

      final daily = DailyPnl.fromJson(json);
      expect(daily.dailyPnl, -320.0);
      expect(daily.cumulativePnl, 2180.0);
    });
  });
}
