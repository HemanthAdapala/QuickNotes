import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/experimental/experimental_quick_notes_liquid_glass_back_button.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_easy_button_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

void main() {
  group('LB-R5: ExperimentalQuickNotesLiquidGlassBackButton Forensic Verification', () {
    testWidgets('1. Geometry: Renders at strictly 44.0 x 44.0 circular dimensions with 22.0px radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExperimentalQuickNotesLiquidGlassBackButton(
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(ExperimentalQuickNotesLiquidGlassBackButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.width, 44.0);
      expect(size.height, 44.0);

      // Verify underlying glass surface is sized 44x44 with radius 22.0
      final glassFinder = find.byType(BottomBarGlassSurface);
      expect(glassFinder, findsOneWidget);
      final glassWidget = tester.widget<BottomBarGlassSurface>(glassFinder);
      expect(glassWidget.width, 44.0);
      expect(glassWidget.height, 44.0);
      expect(glassWidget.borderRadius, BorderRadius.circular(22.0));
    });

    testWidgets('2. Icon: Contains angle_left.svg sized at 22.0 x 22.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExperimentalQuickNotesLiquidGlassBackButton(
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      final svgWidget = tester.widget<SvgPicture>(svgFinder);

      expect(svgWidget.width, 22.0);
      expect(svgWidget.height, 22.0);
      expect((svgWidget.bytesLoader as dynamic).assetName, 'assets/icons/angle_left.svg');
    });

    testWidgets('3. Callback: Fires generic onPressed exactly once upon normal tap', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExperimentalQuickNotesLiquidGlassBackButton(
                onPressed: () {
                  tapCount++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExperimentalQuickNotesLiquidGlassBackButton));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('4. Semantics: Exposes explicit "Back" label as a single actionable button node', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExperimentalQuickNotesLiquidGlassBackButton(
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      final data = tester.getSemantics(find.byType(ExperimentalQuickNotesLiquidGlassBackButton)).getSemanticsData();
      expect(data.label, 'Back');
      expect(data.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('5. Touch & Deformation: Validates press swell, drag stretch, and transverse squeeze at 44x44', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExperimentalQuickNotesLiquidGlassBackButton(
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final glassFinder = find.byType(BottomBarGlassSurface);
      final Rect restRect = tester.getRect(glassFinder);
      expect(restRect.width, 44.0);
      expect(restRect.height, 44.0);

      // A. Press down creates localized outward press swell (+3% holdScale = +1.32px)
      final TestGesture gesture = await tester.createGesture(pointer: 101);
      await gesture.down(restRect.center);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final Rect pressRect = tester.getRect(glassFinder);
      expect(pressRect.width, greaterThan(restRect.width));
      expect(pressRect.height, greaterThan(restRect.height));

      // B. Drag Right creates elongation along pull axis and squeeze on cross axis
      await gesture.moveBy(const Offset(40, 0));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final Rect dragRightRect = tester.getRect(glassFinder);
      expect(dragRightRect.width, greaterThan(pressRect.width));
      expect(dragRightRect.height, lessThan(pressRect.height)); // Transverse squeeze active

      // C. Release returns smoothly to restSize 44x44
      await gesture.up();
      await tester.pumpAndSettle();

      final Rect releasedRect = tester.getRect(glassFinder);
      expect(releasedRect.width, closeTo(44.0, 0.1));
      expect(releasedRect.height, closeTo(44.0, 0.1));
    });

    testWidgets('6. Lab Screen Integration: Switching to LB-R5 mode renders both circular back button and reference button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassEasyButtonLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap LB-R5 Mode Tab
      final backButtonModeTab = find.byKey(const ValueKey('lab_mode_circular_back_button'));
      expect(backButtonModeTab, findsOneWidget);
      await tester.tap(backButtonModeTab);
      await tester.pumpAndSettle();

      // Verify Experimental Circular Back Button and Reference Button are both present
      final circularFinder = find.byKey(const ValueKey('experimental_circular_back_button'));
      final referenceFinder = find.byKey(const ValueKey('reference_standard_button'));
      expect(circularFinder, findsOneWidget);
      expect(referenceFinder, findsOneWidget);

      // Verify tap on experimental back button triggers feedback and increments counter
      await tester.tap(circularFinder);
      await tester.pump();
      expect(find.textContaining('Circular Back Button tapped! (1)'), findsOneWidget);
      await tester.pumpAndSettle();

      // Verify background layers are active underneath
      expect(find.byKey(const ValueKey('background_layer_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('background_layer_2')), findsOneWidget);
    });
  });
}
