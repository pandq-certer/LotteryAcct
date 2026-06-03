import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottery_acct/app.dart';

void main() {
  testWidgets('App renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LotteryAcctApp()));
    expect(find.text('LotteryAcct'), findsWidgets);
  });
}
