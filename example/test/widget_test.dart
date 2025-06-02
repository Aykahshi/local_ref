import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('HomePage renders and navigates to LocalUsagePage',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that HomePage is present.
    expect(find.text('Local Ref Examples'), findsOneWidget);
    expect(find.text('Local Usage Example'), findsOneWidget);
    expect(find.text('RefProvider Example'), findsOneWidget);
    expect(find.text('StoreProvider Example'), findsOneWidget);

    // Tap the 'Local Usage Example' button and trigger a frame.
    await tester.tap(find.text('Local Usage Example'));
    await tester
        .pumpAndSettle(); // pumpAndSettle to wait for animations/transitions

    // Verify that LocalUsagePage is now visible.
    expect(find.text('Local Ref Usage'), findsOneWidget);
    // You can add more specific checks for LocalUsagePage's content here
  });

  testWidgets('HomePage navigates to RefProviderPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('RefProvider Example'));
    await tester.pumpAndSettle();
    expect(find.text('RefProvider Usage'), findsOneWidget);
    // Add more specific checks for RefProviderPage
  });

  testWidgets('HomePage navigates to StoreProviderPage',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('StoreProvider Example'));
    await tester.pumpAndSettle();
    expect(find.text('StoreProvider Usage'), findsOneWidget);
    // Add more specific checks for StoreProviderPage
  });

  // --- LocalUsagePage Tests ---
  group('LocalUsagePage', () {
    testWidgets('renders initial UI and counter works',
        (WidgetTester tester) async {
      // Navigate to LocalUsagePage
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Local Usage Example'));
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Counter: 0'), findsOneWidget);
      expect(find.text('Text: Hello'), findsOneWidget);
      expect(find.text('Combined: Counter is 0 and Text is Hello'),
          findsOneWidget);
      expect(find.text('Counter (via .obs): 0'), findsOneWidget);

      // Tap the increment button for the counter
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify counter updated
      expect(find.text('Counter: 1'), findsOneWidget);
      expect(find.text('Combined: Counter is 1 and Text is Hello'),
          findsOneWidget);
      expect(find.text('Counter (via .obs): 1'), findsOneWidget);
    });

    testWidgets('text field updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Local Usage Example'));
      await tester.pumpAndSettle();

      // Enter text into the TextField
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pump();

      // Verify text updated
      expect(find.text('Text: Flutter'), findsOneWidget);
      expect(find.text('Combined: Counter is 0 and Text is Flutter'),
          findsOneWidget);
    });
  });

  // --- RefProviderPage Tests ---
  group('RefProviderPage', () {
    testWidgets('renders initial UI and counter works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('RefProvider Example'));
      await tester.pumpAndSettle();

      // Verify initial state (assuming initial value of providedCounter is 100)
      expect(
          find.text('Provided Counter (via RefConsumer): 100'), findsOneWidget);
      expect(
          find.text('Provided Counter (via context.ref): 100'), findsOneWidget);

      // Tap the increment button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify counter updated
      expect(
          find.text('Provided Counter (via RefConsumer): 101'), findsOneWidget);
      expect(
          find.text('Provided Counter (via context.ref): 101'), findsOneWidget);
    });
  });

  // --- StoreProviderPage Tests ---
  group('StoreProviderPage', () {
    testWidgets('renders initial UI and counter works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('StoreProvider Example'));
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Counter (StoreSelector): 0'), findsOneWidget);
      expect(
          find.text('Name (StoreSelector): User from Store'), findsOneWidget);
      expect(find.text('Is Dark Mode (StoreSelector): false'), findsOneWidget);
      expect(find.text('Counter (StoreConsumer): 0'), findsOneWidget);
      expect(find.text('Counter (via context.storeValue): 0'), findsOneWidget);
      expect(find.text('Counter (Store key .obs): 0'), findsOneWidget);

      // Tap the 'Increment Counter' button
      await tester.tap(find.text('Increment Counter'));
      await tester.pump();

      // Verify counter updated across relevant widgets
      expect(find.text('Counter (StoreSelector): 1'), findsOneWidget);
      expect(find.text('Counter (StoreConsumer): 1'), findsOneWidget);
      expect(find.text('Counter (via context.storeValue): 1'), findsOneWidget);
      expect(find.text('Counter (Store key .obs): 1'), findsOneWidget);
    });

    testWidgets('name field updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('StoreProvider Example'));
      await tester.pumpAndSettle();

      // Enter text into the TextField for name
      await tester.enterText(
          find.widgetWithText(TextField, 'Name'), 'Test User');
      await tester.pump();

      // Verify name updated
      expect(find.text('Name (StoreSelector): Test User'), findsOneWidget);
    });

    testWidgets('toggle dark mode updates UI', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('StoreProvider Example'));
      await tester.pumpAndSettle();

      // Tap the 'Toggle Dark Mode' button
      await tester.tap(find.text('Toggle Dark Mode'));
      await tester.pump();

      // Verify dark mode updated
      expect(find.text('Is Dark Mode (StoreSelector): true'), findsOneWidget);

      // Tap again to toggle back
      await tester.tap(find.text('Toggle Dark Mode'));
      await tester.pump();
      expect(find.text('Is Dark Mode (StoreSelector): false'), findsOneWidget);
    });
  });
}
