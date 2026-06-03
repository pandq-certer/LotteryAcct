import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/models/betting_record.dart';

void main() {
  group('BettingRecord', () {
    final baseJson = {
      'id': 'abc-123',
      'user_id': 'user-1',
      'bet_type': 'single',
      'category': 'football',
      'match_name': '皇马 vs 巴萨',
      'play_type': '让球',
      'odds': 1.85,
      'stake': 500.0,
      'potential_return': 925.0,
      'result_amount': 425.0,
      'status': 'won',
      'note': '备注',
      'ticket_image_url': 'https://example.com/img.jpg',
      'settled_at': '2026-06-01T21:30:00Z',
      'created_at': '2026-06-01T20:00:00Z',
    };

    test('fromJson parses all fields correctly', () {
      final record = BettingRecord.fromJson(baseJson);

      expect(record.id, 'abc-123');
      expect(record.userId, 'user-1');
      expect(record.betType, BetType.single);
      expect(record.category, BetCategory.football);
      expect(record.matchName, '皇马 vs 巴萨');
      expect(record.playType, '让球');
      expect(record.odds, 1.85);
      expect(record.stake, 500.0);
      expect(record.potentialReturn, 925.0);
      expect(record.resultAmount, 425.0);
      expect(record.status, BetStatus.won);
      expect(record.note, '备注');
      expect(record.ticketImageUrl, 'https://example.com/img.jpg');
      expect(record.settledAt, isNotNull);
      expect(record.createdAt, isNotNull);
    });

    test('fromJson handles null optional fields', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['match_name'] = null
        ..['result_amount'] = null
        ..['note'] = null
        ..['ticket_image_url'] = null
        ..['settled_at'] = null;

      final record = BettingRecord.fromJson(json);

      expect(record.matchName, isNull);
      expect(record.resultAmount, isNull);
      expect(record.note, '');
      expect(record.ticketImageUrl, isNull);
      expect(record.settledAt, isNull);
    });

    test('fromJson handles parlay bet type', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['bet_type'] = 'parlay'
        ..['category'] = 'basketball';

      final record = BettingRecord.fromJson(json);

      expect(record.betType, BetType.parlay);
      expect(record.category, BetCategory.basketball);
    });

    test('fromJson handles all bet statuses', () {
      for (final status in ['pending', 'won', 'lost', 'partial', 'voided']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = status;
        final record = BettingRecord.fromJson(json);
        expect(record.status.name, status);
      }
    });

    test('fromJson handles all categories', () {
      for (final cat in ['football', 'basketball', 'tennis', 'other']) {
        final json = Map<String, dynamic>.from(baseJson)..['category'] = cat;
        final record = BettingRecord.fromJson(json);
        expect(record.category.name, cat);
      }
    });

    test('toJson outputs correct map', () {
      final record = BettingRecord.fromJson(baseJson);
      final json = record.toJson();

      expect(json['user_id'], 'user-1');
      expect(json['bet_type'], 'single');
      expect(json['category'], 'football');
      expect(json['match_name'], '皇马 vs 巴萨');
      expect(json['play_type'], '让球');
      expect(json['odds'], 1.85);
      expect(json['stake'], 500.0);
      expect(json['status'], 'won');
      expect(json['note'], '备注');
    });

    test('pnl returns resultAmount when set', () {
      final record = BettingRecord.fromJson(baseJson);
      expect(record.pnl, 425.0);
    });

    test('pnl returns 0 when resultAmount is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['result_amount'] = null;
      final record = BettingRecord.fromJson(json);
      expect(record.pnl, 0);
    });

    test('isSettled is true for won/lost/partial/voided', () {
      for (final status in ['won', 'lost', 'partial', 'voided']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = status;
        final record = BettingRecord.fromJson(json);
        expect(record.isSettled, isTrue);
      }
    });

    test('isSettled is false for pending', () {
      final json = Map<String, dynamic>.from(baseJson)..['status'] = 'pending';
      final record = BettingRecord.fromJson(json);
      expect(record.isSettled, isFalse);
    });

    test('isPositive returns true for positive resultAmount', () {
      final record = BettingRecord.fromJson(baseJson);
      expect(record.isPositive, isTrue);
    });

    test('isPositive returns false for negative resultAmount', () {
      final json = Map<String, dynamic>.from(baseJson)..['result_amount'] = -100.0;
      final record = BettingRecord.fromJson(json);
      expect(record.isPositive, isFalse);
    });

    test('isPositive returns false when resultAmount is null', () {
      final json = Map<String, dynamic>.from(baseJson)..['result_amount'] = null;
      final record = BettingRecord.fromJson(json);
      expect(record.isPositive, isFalse);
    });
  });
}
