import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'user-abc',
        'display_name': '阿强',
        'created_at': '2026-01-15T10:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-abc');
      expect(profile.displayName, '阿强');
      expect(profile.createdAt.year, 2026);
    });

    test('fromJson handles null display_name', () {
      final json = {
        'id': 'user-abc',
        'display_name': null,
        'created_at': '2026-01-15T10:00:00Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.displayName, '');
    });

    test('fromJson parses date correctly', () {
      final json = {
        'id': 'user-abc',
        'display_name': 'Test',
        'created_at': '2026-06-03T14:30:00Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.createdAt.month, 6);
      expect(profile.createdAt.day, 3);
      expect(profile.createdAt.hour, 14);
    });
  });
}
