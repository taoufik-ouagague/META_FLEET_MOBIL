import 'package:flutter_test/flutter_test.dart';
import 'package:meta_fleet/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MetaFleetApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MetaFleetApp());
    // Pump frames to let splash timer complete
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(MetaFleetApp), findsOneWidget);
  });
}
