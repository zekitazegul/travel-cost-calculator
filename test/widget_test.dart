import 'package:flutter_test/flutter_test.dart';

import 'package:travel_cost_calculator/main.dart';

void main() {
  testWidgets('Travel Cost Calculator loads', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelCostCalculatorApp());

    expect(find.text('Travel Cost Calculator'), findsOneWidget);
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Pricing'), findsOneWidget);
    expect(find.text('Calculate Route'), findsOneWidget);
  });
}
