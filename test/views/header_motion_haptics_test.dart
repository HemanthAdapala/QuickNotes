import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTactileButtonHarness({
    required VoidCallback onTap,
    bool enabled = true,
    bool disableAnimations = false,
    double compressionScale = 0.94,
    Duration pressDuration = QuickNotesMotion.kMotionMicro,
    Duration settleDuration = QuickNotesMotion.kMotionRelease,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: TactileButton(
              onTap: onTap,
              enabled: enabled,
              compressionScale: compressionScale,
              pressDuration: pressDuration,
              settleDuration: settleDuration,
              child: const SizedBox(
                width: 44.0,
                height: 44.0,
                child: Text('Button'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeaderHarness({
    bool isExpanded = false,
    bool disableAnimations = false,
    double rightWidth = 44.0,
    double expandedWidth = 192.0,
    double expandedHeight = 100.0,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        size: const Size(402.0, 800.0),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: SizedBox(
              width: 402.0,
              child: AppHeaderBar(
                isExpanded: isExpanded,
                rightWidth: rightWidth,
                expandedWidth: expandedWidth,
                expandedHeight: expandedHeight,
                leftChild: const Icon(Icons.arrow_back),
                rightChild: const Icon(Icons.more_horiz),
                expandedChild: const Text('Menu'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Phase P3.5 — Test A: Tactile Scale Normalization', () {
    testWidgets('compresses towards 0.94 on pointer-down and never 0.70', (tester) async {
      await tester.pumpWidget(buildTactileButtonHarness(onTap: () {}));

      // Find ScaleTransition
      final scaleFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);

      final scaleWidgetBefore = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetBefore.scale.value, 1.0);

      // Trigger pointer down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump(const Duration(milliseconds: 100)); // Tap down timeout (kPressTimeout)
      await tester.pump(QuickNotesMotion.kMotionMicro); // complete kMotionMicro

      final scaleWidgetPressed = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetPressed.scale.value, closeTo(0.94, 0.005));
      expect(scaleWidgetPressed.scale.value, isNot(closeTo(0.70, 0.05)));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      final scaleWidgetReleased = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetReleased.scale.value, closeTo(1.0, 0.005));
    });
  });

  group('Phase P3.5 — Test B: Motion Tokens Verification', () {
    testWidgets('TactileButton defaults to QuickNotesMotion tokens', (tester) async {
      const button = TactileButton(
        onTap: _dummyCallback,
        child: SizedBox(),
      );

      expect(button.compressionScale, 0.94);
      expect(button.pressDuration, QuickNotesMotion.kMotionMicro);
      expect(button.settleDuration, QuickNotesMotion.kMotionRelease);
    });
  });

  group('Phase P3.5 — Test C: Reduced Motion Contract', () {
    testWidgets('scale remains exactly 1.0 throughout press when disableAnimations is true', (tester) async {
      await tester.pumpWidget(buildTactileButtonHarness(
        onTap: () {},
        disableAnimations: true,
      ));

      final scaleFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);

      final scaleWidgetBefore = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetBefore.scale.value, 1.0);

      // Pointer down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump(const Duration(milliseconds: 45));

      final scaleWidgetMid = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetMid.scale.value, 1.0);

      await tester.pump(const Duration(milliseconds: 90));
      final scaleWidgetFull = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetFull.scale.value, 1.0);

      await gesture.up();
      await tester.pumpAndSettle();

      final scaleWidgetEnd = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidgetEnd.scale.value, 1.0);
    });
  });

  group('Phase P3.5 — Test D: Disabled Button Contract', () {
    testWidgets('disabled button does not scale, does not emit haptic, and does not invoke callback', (tester) async {
      int tapCount = 0;
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      await tester.pumpWidget(buildTactileButtonHarness(
        onTap: () => tapCount++,
        enabled: false,
      ));

      final scaleFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );

      // Attempt tap
      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump(const Duration(milliseconds: 90));

      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidget.scale.value, 1.0); // no compression
      expect(haptics, isEmpty); // no haptic on down

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapCount, 0); // callback not called
      expect(haptics, isEmpty); // no haptic on up

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  group('Phase P3.5 — Test E & F: Single Haptic & Double-Fire Prevention', () {
    testWidgets('pointer-down + pointer-up produces exactly ONE buttonPress haptic event', (tester) async {
      int tapCount = 0;
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      await tester.pumpWidget(buildTactileButtonHarness(
        onTap: () => tapCount++,
        enabled: true,
      ));

      // Pointer down
      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump();

      // Exactly 1 haptic on touch-down
      expect(haptics, ['buttonPress']);

      // Pointer up
      await gesture.up();
      await tester.pumpAndSettle();

      // Tap fired once, and NO duplicate haptic on touch-up
      expect(tapCount, 1);
      expect(haptics.length, 1);
      expect(haptics, ['buttonPress']);

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  group('Phase P3.5 — Test G: Reduced Motion + Haptics', () {
    testWidgets('reduced motion suppresses scale animation but preserves semantic haptic', (tester) async {
      int tapCount = 0;
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      await tester.pumpWidget(buildTactileButtonHarness(
        onTap: () => tapCount++,
        disableAnimations: true,
      ));

      final scaleFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Button')));
      await tester.pump(const Duration(milliseconds: 90));

      // Visual scale remains 1.0
      expect(tester.widget<ScaleTransition>(scaleFinder).scale.value, 1.0);

      // Semantic haptic STILL fires
      expect(haptics, ['buttonPress']);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapCount, 1);
      expect(haptics.length, 1);

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  group('Phase P3.5 — Test H & I: Header Expansion & Collapse Dimensions', () {
    testWidgets('structural expansion expands to 192px and collapses back to 44px', (tester) async {
      // Collapsed
      await tester.pumpWidget(buildHeaderHarness(isExpanded: false));
      final rightContainerFinder = find.byType(AnimatedContainer);
      expect(tester.getSize(rightContainerFinder).width, 44.0);
      expect(tester.getSize(rightContainerFinder).height, 44.0);

      // Expand
      await tester.pumpWidget(buildHeaderHarness(isExpanded: true));
      await tester.pumpAndSettle();
      expect(tester.getSize(rightContainerFinder).width, 192.0);
      expect(tester.getSize(rightContainerFinder).height, 100.0);

      // Collapse back
      await tester.pumpWidget(buildHeaderHarness(isExpanded: false));
      await tester.pumpAndSettle();
      expect(tester.getSize(rightContainerFinder).width, 44.0);
      expect(tester.getSize(rightContainerFinder).height, 44.0);
    });
  });

  group('Phase P3.5 — Test J: Tokenized Structural Animation', () {
    testWidgets('AppHeaderBar default durations match QuickNotesMotion tokens', (tester) async {
      const header = AppHeaderBar();
      expect(header.expandDuration, QuickNotesMotion.kMotionPage);
      expect(header.shrinkDuration, QuickNotesMotion.kMotionPageReverse);
      expect(header.expandCurve, QuickNotesMotion.kMotionAppleEase);
      expect(header.shrinkCurve, QuickNotesMotion.kMotionAppleEase);
    });
  });
}

void _dummyCallback() {}
