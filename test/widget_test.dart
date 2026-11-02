
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/main.dart';

void main() {
  testWidgets('Calorie Tracker app smoke test',
          (WidgetTester tester) async {

        // Build the application
        await tester.pumpWidget(const CalorieTrackerApp());

        // Check app title
        expect(find.text('Calorie Tracker'), findsOneWidget);

        // Check initial food list
        expect(find.text('No meals logged yet'), findsOneWidget);

        // Tap Add Food button
        await tester.tap(find.text('Add Food').first);
        await tester.pumpAndSettle();

        // Enter food information
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Chicken',
        );

        await tester.enterText(
          find.byType(TextFormField).at(1),
          '250',
        );

        // Submit food
        await tester.tap(find.text('Add Food').last);
        await tester.pumpAndSettle();

        // Verify food was added
        expect(find.text('Chicken'), findsOneWidget);
        expect(find.text('250'), findsWidgets);
      });
}
