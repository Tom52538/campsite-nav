import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camping_osm_navi/widgets/route_info_display.dart';

void main() {
  Widget buildTestableWidget(double? distance, int? time) {
    return MaterialApp(
      home: Scaffold(
        body: Stack( // RouteInfoDisplay uses Positioned, so a Stack is needed
          children: [
            RouteInfoDisplay(
              distanceInMeters: distance,
              timeInMinutes: time,
            ),
          ],
        ),
      ),
    );
  }

  group('RouteInfoDisplay Widget Tests', () {
    testWidgets('Displays nothing when data is null for distance', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(null, 5));
      expect(find.byType(SizedBox), findsOneWidget);
      // Check that no part of the actual display UI is present
      expect(find.textContaining('m'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.byIcon(Icons.route_outlined), findsNothing);
    });

    testWidgets('Displays nothing when data is null for time', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(500, null));
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.textContaining('m'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.byIcon(Icons.route_outlined), findsNothing);
    });

    testWidgets('Displays nothing when distance is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(0, 5));
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.textContaining('m'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.byIcon(Icons.route_outlined), findsNothing);
    });

    testWidgets('Displays distance in meters and time in minutes', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(800, 8));
      await tester.pumpAndSettle();

      expect(find.text('800 m'), findsOneWidget);
      expect(find.text('8 min'), findsOneWidget);
      expect(find.descendant(of: find.byType(RouteInfoDisplay), matching: find.byType(Material)), findsOneWidget);
    });

    testWidgets('Displays distance in kilometers and time in minutes', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(1250, 13));
      await tester.pumpAndSettle();

      expect(find.text('1.3 km'), findsOneWidget);
      expect(find.text('13 min'), findsOneWidget);
      expect(find.descendant(of: find.byType(RouteInfoDisplay), matching: find.byType(Material)), findsOneWidget);
    });

    testWidgets('Displays distance in kilometers (rounded to one decimal) and time in minutes', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(1000, 10));
      await tester.pumpAndSettle();

      expect(find.text('1.0 km'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.descendant(of: find.byType(RouteInfoDisplay), matching: find.byType(Material)), findsOneWidget);
    });

    testWidgets('Displays icons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(500, 5));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.descendant(of: find.byType(RouteInfoDisplay), matching: find.byType(Material)), findsOneWidget);
    });
  });
}
