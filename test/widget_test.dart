import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const HappyPlantsApp());
    expect(find.byType(HappyPlantsApp), findsOneWidget);
  });
}
