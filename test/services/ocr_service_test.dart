import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/services/ocr_service.dart';

void main() {
  group('OcrResult', () {
    test('fromJson parses single bet correctly', () {
      final json = {
        'match_name': '皇马 vs 巴萨',
        'play_type': '让球',
        'odds': 1.85,
        'stake': 500.0,
        'category': 'football',
        'bet_type': 'single',
        'legs': null,
      };

      final result = OcrResult.fromJson(json);

      expect(result.matchName, '皇马 vs 巴萨');
      expect(result.playType, '让球');
      expect(result.odds, 1.85);
      expect(result.stake, 500.0);
      expect(result.category, 'football');
      expect(result.betType, 'single');
      expect(result.legs, isNull);
    });

    test('fromJson parses parlay with legs', () {
      final json = {
        'match_name': null,
        'play_type': '',
        'odds': 6.3,
        'stake': 200.0,
        'category': 'football',
        'bet_type': 'parlay',
        'legs': [
          {'match_name': '皇马 vs 巴萨', 'odds': 1.85},
          {'match_name': '曼城 vs 利物浦', 'odds': 2.10},
          {'match_name': '拜仁 vs 多特', 'odds': 1.62},
        ],
      };

      final result = OcrResult.fromJson(json);

      expect(result.matchName, isNull);
      expect(result.betType, 'parlay');
      expect(result.legs, isNotNull);
      expect(result.legs!.length, 3);
      expect(result.legs![0].matchName, '皇马 vs 巴萨');
      expect(result.legs![0].odds, 1.85);
      expect(result.legs![2].matchName, '拜仁 vs 多特');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'match_name': null,
        'play_type': '',
        'odds': null,
        'stake': null,
        'category': 'football',
        'bet_type': 'single',
        'legs': null,
      };

      final result = OcrResult.fromJson(json);

      expect(result.odds, isNull);
      expect(result.stake, isNull);
      expect(result.legs, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final result = OcrResult.fromJson(json);

      expect(result.matchName, isNull);
      expect(result.playType, '');
      expect(result.category, 'football');
      expect(result.betType, 'single');
      expect(result.odds, isNull);
    });
  });

  group('OcrLeg', () {
    test('fromJson parses correctly', () {
      final json = {'match_name': '湖人 vs 勇士', 'odds': 2.25};

      final leg = OcrLeg.fromJson(json);

      expect(leg.matchName, '湖人 vs 勇士');
      expect(leg.odds, 2.25);
    });
  });
}
