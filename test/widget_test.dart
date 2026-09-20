import 'package:flutter_test/flutter_test.dart';
import 'package:travel_cost_calculator/main.dart';

void main() {
  testWidgets('Travel Cost Calculator loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelCostCalculatorApp());

    expect(find.text('Travel Cost Calculator'), findsOneWidget);
    expect(find.text('Calculate your travel cost'), findsOneWidget);
    expect(find.text('Start address'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('€ 0.25'), findsNothing);
    expect(find.text('0.0 km'), findsOneWidget);
  });
}