import 'package:flutter_test/flutter_test.dart';
import 'package:mirrormind_flutter/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MirrorMindApp());
    expect(find.text('MirrorMind'), findsOneWidget);
  });
}
