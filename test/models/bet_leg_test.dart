import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/models/bet_leg.dart';

void main() {
  group('BetLeg', () {
    final baseJson = {
      'id': 'leg-1',
      'record_id': 'record-1',
      'match_name': '皇马 vs 巴萨',
      'play_type': '让球',
      'odds': 1.85,
      'result_amount': 425.0,
      'status': 'won',
      'created_at': '2026-06-01T20:00:00Z',
    };

    test('fromJson parses all fields correctly', () {
      final leg = BetLeg.fromJson(baseJson);

      expect(leg.id, 'leg-1');
      expect(leg.recordId, 'record-1');
      expect(leg.matchName, '皇马 vs 巴萨');
      expect(leg.playType, '让球');
      expect(leg.odds, 1.85);
      expect(leg.resultAmount, 425.0);
      expect(leg.status, BetLegStatus.won);
      expect(leg.createdAt, isNotNull);
    });

    test('fromJson handles null resultAmount', () {
      final json = Map<String, dynamic>.from(baseJson)..['result_amount'] = null;
      final leg = BetLeg.fromJson(json);
      expect(leg.resultAmount, isNull);
    });

    test('fromJson handles missing play_type gracefully', () {
      final json = Map<String, dynamic>.from(baseJson)..['play_type'] = null;
      final leg = BetLeg.fromJson(json);
      expect(leg.playType, '');
    });

    test('fromJson handles all statuses', () {
      for (final status in ['pending', 'won', 'lost', 'partial', 'voided']) {
        final json = Map<String, dynamic>.from(baseJson)..['status'] = status;
        final leg = BetLeg.fromJson(json);
        expect(leg.status.name, status);
      }
    });

    test('toJson outputs correct map with parentRecordId', () {
      final leg = BetLeg.fromJson(baseJson);
      final json = leg.toJson('parent-123');

      expect(json['record_id'], 'parent-123');
      expect(json['match_name'], '皇马 vs 巴萨');
      expect(json['play_type'], '让球');
      expect(json['odds'], 1.85);
      expect(json['status'], 'won');
    });
  });
}
