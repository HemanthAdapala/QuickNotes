import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_button.dart';

void main() {
  group('QuickNotesLiquidGlassButton Tests', () {
    testWidgets('renders default Create Folder label and BottomBarGlassSurface',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Folder'), findsOneWidget);
      expect(find.byType(BottomBarGlassSurface), findsOneWidget);
      expect(find.byType(QuickNotesLiquidGlassButton), findsOneWidget);

      await tester.tap(find.byType(QuickNotesLiquidGlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders custom label and custom child',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () {},
                label: 'Save Note',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save Note'), findsOneWidget);

      // Custom child override
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, key: ValueKey('custom_icon')),
                    SizedBox(width: 4),
                    Text('Done'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom_icon')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('respects enabled: false', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () => tapped = true,
                enabled: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(QuickNotesLiquidGlassButton));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);

      // Verify Semantics
      final data = tester.getSemantics(find.byType(QuickNotesLiquidGlassButton)).getSemanticsData();
      expect(data.label, equals('Create Folder'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, equals(Tristate.isFalse));
    });

    testWidgets('clean baseline mode (enableFlex: false) renders static glass without flex listener',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () => tapped = true,
                enableFlex: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('stage2_clean_baseline_gesture')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage2_experimental_flex_listener')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('stage2_clean_baseline_gesture')));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('press swell and drag response under flex mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassButton(
                onTap: () {},
                width: 200.0,
                height: 50.0,
                enableFlex: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final glassFinder = find.byType(BottomBarGlassSurface);
      expect(glassFinder, findsOneWidget);
      final Rect restRect = tester.getRect(glassFinder);
      expect(restRect.width, equals(200.0));
      expect(restRect.height, equals(50.0));

      // Pointer Down -> Press Swell
      final TestGesture gesture = await tester.createGesture(pointer: 1);
      await gesture.down(restRect.center);
      await tester.pump(const Duration(milliseconds: 60));

      final Rect pressRect = tester.getRect(glassFinder);
      expect(pressRect.width, greaterThan(restRect.width));
      expect(pressRect.height, greaterThan(restRect.height));

      // Drag Right -> Stretch + Transverse Squeeze
      await gesture.moveBy(const Offset(48, 0));
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final Rect dragRect = tester.getRect(glassFinder);
      expect(dragRect.width, greaterThan(restRect.width));
      expect(dragRect.height, lessThan(restRect.height)); // Squeeze active

      await gesture.up();
      await tester.pumpAndSettle();

      final Rect settledRect = tester.getRect(glassFinder);
      expect(settledRect.width, closeTo(restRect.width, 0.5));
      expect(settledRect.height, closeTo(restRect.height, 0.5));
    });

    testWidgets('lifecycle disposal cleanly disposes flex driver',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNotesLiquidGlassButton(
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Remove from widget tree
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuickNotesLiquidGlassButton), findsNothing);
    });
  });
}
