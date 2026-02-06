// Basic widget test for Daily MicroRituals
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_micro_rituals/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DailyMicroRitualsApp());

    // Verify that the home screen renders with expected elements
    expect(find.text('Your micro-rituals'), findsOneWidget);
    expect(find.text('Today\'s Progress'), findsOneWidget);
  });
}
