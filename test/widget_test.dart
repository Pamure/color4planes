// test/widget_test.dart
//
// FIX: The auto-generated test referenced 'MyApp' which doesn't exist.
// The app's root widget is 'ColorPlanesApp' (defined in lib/main.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:color4planes/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ColorPlanesApp());
    // Just verify the app renders without throwing
    expect(find.byType(ColorPlanesApp), findsOneWidget);
  });
}
