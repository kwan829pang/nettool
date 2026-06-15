import 'package:flutter_test/flutter_test.dart';

import 'package:net_tool/main.dart';

void main() {
  testWidgets('App loads with network scan panel', (WidgetTester tester) async {
    await tester.pumpWidget(const NetToolApp());

    expect(find.text('Network Scan'), findsWidgets);
    expect(find.text('Port Scan'), findsOneWidget);
    expect(find.text('Speed Test'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
  });
}
