import 'package:flutter_test/flutter_test.dart';
import 'package:lottery_acct/shared/providers/error_handler.dart';

void main() {
  group('AppErrorHandler', () {
    test('returns generic message for unknown errors', () {
      final msg = AppErrorHandler.getLocalizedMessage(Exception('unknown'));
      expect(msg, '操作失败，请稍后重试');
    });

    test('returns generic message for string errors', () {
      final msg = AppErrorHandler.getLocalizedMessage('something broke');
      expect(msg, '操作失败，请稍后重试');
    });

    test('handles null errors gracefully', () {
      final msg = AppErrorHandler.getLocalizedMessage(null);
      expect(msg, '操作失败，请稍后重试');
    });
  });
}
