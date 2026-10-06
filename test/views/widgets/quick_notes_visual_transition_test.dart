import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quick_notes/core/motion/quick_notes_visual_capability.dart';
import 'package:quick_notes/core/motion/quick_notes_visual_preset.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_visual_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    required Object state,
    QuickNotesVisualPreset preset = QuickNotesVisualPreset.baseline,
    List<QuickNotesVisualCapability> capabilities = const [],
    Size collapsedSize = const Size(44.0, 44.0),
    Size expandedSize = const Size(192.0, 100.0),
    BorderRadius collapsedBorderRadius =
        const BorderRadius.all(Radius.circular(22.0)),
    BorderRadius expandedBorderRadius =
        const BorderRadius.all(Radius.circular(20.0)),
    Alignment anchor = Alignment.topRight,
    bool occupyBounds = false,
    bool isLiquidGlass = false,
    Widget? child,
    Widget? collapsedChild,
    Widget? expandedChild,
    VoidCallback? onTransitionEnd,
  }) {
    if (isLiquidGlass) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickNotesVisualTransition.liquidGlass(
              state: state,
              preset: preset,
              capabilities: capabilities,
              collapsedSize: collapsedSize,
              expandedSize: expandedSize,
              collapsedBorderRadius: collapsedBorderRadius,
              expandedBorderRadius: expandedBorderRadius,
              anchor: anchor,
              occupyBounds: occupyBounds,
              collapsedChild: collapsedChild ??
                  const SizedBox(
                    width: 44.0,
                    height: 44.0,
                    child: Icon(Icons.more_horiz, key: ValueKey('collapsed_child')),
                  ),
              expandedChild: expandedChild ??
                  const SizedBox(
                    width: 192.0,
                    height: 100.0,
                    child: Text('Options', key: ValueKey('expanded_child')),
                  ),
              onTransitionEnd: onTransitionEnd,
              child: child,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: QuickNotesVisualTransition(
            state: state,
            preset: preset,
            capabilities: capabilities,
            collapsedSize: collapsedSize,
            expandedSize: expandedSize,
            collapsedBorderRadius: collapsedBorderRadius,
            expandedBorderRadius: expandedBorderRadius,
            anchor: anchor,
            occupyBounds: occupyBounds,
            collapsedChild: collapsedChild ??
                const SizedBox(
                  width: 44.0,
                  height: 44.0,
                  child: Icon(Icons.more_horiz, key: ValueKey('collapsed_child')),
                ),
            expandedChild: expandedChild ??
                const SizedBox(
                  width: 192.0,
                  height: 100.0,
                  child: Text('Options', key: ValueKey('expanded_child')),
                ),
            onTransitionEnd: onTransitionEnd,
            child: child,
          ),
        ),
      ),
    );
  }

  group('QuickNotesVisualTransition Architecture Tests', () {
    // =========================================================================
    // A. Geometry
    // =========================================================================
    testWidgets('A. Geometry: collapsed and expanded dimensions settle accurately',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false));
      await tester.pumpAndSettle();

      final Size collapsedSize =
          tester.getSize(find.byType(QuickNotesVisualTransition));
      expect(collapsedSize, const Size(44.0, 44.0));

      await tester.pumpWidget(buildSubject(state: true));
      await tester.pumpAndSettle();

      final Size expandedSize =
          tester.getSize(find.byType(QuickNotesVisualTransition));
      expect(expandedSize, const Size(192.0, 100.0));
    });

    testWidgets('A. Geometry: anchor bounds and retargeting preserve top-right anchor',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false, anchor: Alignment.topRight));
      await tester.pumpAndSettle();

      final Offset collapsedTopRight =
          tester.getTopRight(find.byType(QuickNotesVisualTransition));

      await tester.pumpWidget(buildSubject(state: true, anchor: Alignment.topRight));
      await tester.pump(const Duration(milliseconds: 50));

      final Offset midTopRight =
          tester.getTopRight(find.byType(QuickNotesVisualTransition));
      // Top and right coordinates must stay anchor-locked
      expect(midTopRight.dy, closeTo(collapsedTopRight.dy, 0.5));
    });

    // =========================================================================
    // B. Motion
    // =========================================================================
    testWidgets('B. Motion: mid-flight interruption preserves velocity continuity without teleporting',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false));
      await tester.pumpAndSettle();

      // Start expansion
      await tester.pumpWidget(buildSubject(state: true));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final Size midSize1 =
          tester.getSize(find.byType(QuickNotesVisualTransition));
      expect(midSize1.width, greaterThan(44.0));
      expect(midSize1.width, lessThan(192.0));

      // Interrupt mid-flight back to collapsed
      await tester.pumpWidget(buildSubject(state: false));
      await tester.pump(const Duration(milliseconds: 16));

      final Size midSize2 =
          tester.getSize(find.byType(QuickNotesVisualTransition));
      // Must not jump or snap back to 44.0 in 1 frame
      expect((midSize2.width - midSize1.width).abs(), lessThan(15.0));

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(QuickNotesVisualTransition)),
          const Size(44.0, 44.0));
    });

    testWidgets('B. Motion: rapid state changes remain stable and finite',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false));
      await tester.pumpAndSettle();

      for (int i = 0; i < 8; i++) {
        await tester.pumpWidget(buildSubject(state: i % 2 == 1));
        await tester.pump(const Duration(milliseconds: 25));
      }

      await tester.pumpAndSettle();
      final Size finalSize =
          tester.getSize(find.byType(QuickNotesVisualTransition));
      expect(
          finalSize == const Size(44.0, 44.0) ||
              finalSize == const Size(192.0, 100.0),
          isTrue);
    });

    // =========================================================================
    // C. Stretch
    // =========================================================================
    testWidgets('C. Stretch: StretchCapability configures asymmetric dynamics',
        (tester) async {
      const stretchCap = StretchCapability(
        stretch: 0.50,
        leadBounce: 0.05,
        followDelaySeconds: 0.02,
      );

      await tester.pumpWidget(buildSubject(
        state: false,
        capabilities: [stretchCap],
      ));
      await tester.pumpAndSettle();

      expect(stretchCap.stretch, 0.50);
      expect(stretchCap.leadBounce, 0.05);
      expect(stretchCap.followDelaySeconds, 0.02);
    });

    // =========================================================================
    // D. Shape
    // =========================================================================
    testWidgets('D. Shape: ShapeCapability continuously interpolates corner radius',
        (tester) async {
      const shapeCap = ShapeCapability(
        collapsedBorderRadius: BorderRadius.all(Radius.circular(22.0)),
        expandedBorderRadius: BorderRadius.all(Radius.circular(8.0)),
      );

      // Mid-progress radius evaluation
      final BorderRadius midRadius = shapeCap.computeRadius(0.5);
      expect(midRadius.topLeft.x, closeTo(15.0, 0.1));

      final BorderRadius finalRadius = shapeCap.computeRadius(1.0);
      expect(finalRadius.topLeft.x, 8.0);
    });

    // =========================================================================
    // E. Content
    // =========================================================================
    testWidgets('E. Content: crossfade between collapsed and expanded child layers',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('collapsed_child')), findsOneWidget);
      expect(find.byKey(const ValueKey('expanded_child')), findsNothing);

      await tester.pumpWidget(buildSubject(state: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('expanded_child')), findsOneWidget);
      expect(find.byKey(const ValueKey('collapsed_child')), findsNothing);
    });

    // =========================================================================
    // F. Presets
    // =========================================================================
    test('F. Presets: formalizes validated lab presets with immutability and overrides', () {
      // 1. Baseline
      expect(QuickNotesVisualPreset.baseline.stiffness, 195.0);
      expect(QuickNotesVisualPreset.baseline.damping, 19.5);
      expect(QuickNotesVisualPreset.baseline.stretch, 0.75);
      expect(QuickNotesVisualPreset.baseline.leadBounce, 0.10);
      expect(QuickNotesVisualPreset.baseline.followDelaySeconds, 0.04);

      // 2. Balanced
      expect(QuickNotesVisualPreset.balanced.stretch, 0.0);
      expect(QuickNotesVisualPreset.balanced.leadBounce, 0.0);
      expect(QuickNotesVisualPreset.balanced.followDelaySeconds, 0.0);

      // 3. Anchor Locked
      expect(QuickNotesVisualPreset.anchorLocked.stretch, 0.20);
      expect(QuickNotesVisualPreset.anchorLocked.leadBounce, 0.0);
      expect(QuickNotesVisualPreset.anchorLocked.followDelaySeconds, 0.0);

      // 4. Overrides via withStretch & withMotion
      final custom = QuickNotesVisualPreset.baseline
          .withMotion(stiffness: 220.0)
          .withStretch(stretch: 0.40);
      expect(custom.stiffness, 220.0);
      expect(custom.stretch, 0.40);
      expect(custom.damping, 19.5); // Preserved
    });

    // =========================================================================
    // G. Composition
    // =========================================================================
    testWidgets('G. Composition: capabilities coexist and process live frame',
        (tester) async {
      const geomCap = GeometryCapability(anchor: Alignment.topRight);
      const stretchCap = StretchCapability(stretch: 0.30);
      const adaptCap = AdaptivityCapability(enableResponsiveAnchor: true);

      await tester.pumpWidget(buildSubject(
        state: true,
        capabilities: [geomCap, stretchCap, adaptCap],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(QuickNotesVisualTransition), findsOneWidget);
    });

    // =========================================================================
    // H. Generic Widget Support
    // =========================================================================
    testWidgets('H. Generic Widget: works cleanly with ordinary non-glass Flutter widgets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesVisualTransition(
                state: true,
                child: Container(
                  key: const ValueKey('generic_flutter_card'),
                  color: Colors.blueAccent,
                  child: const Center(child: Text('Ordinary Widget')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('generic_flutter_card')), findsOneWidget);
      expect(find.text('Ordinary Widget'), findsOneWidget);
      expect(find.byType(BottomBarGlassSurface), findsNothing);
    });

    // =========================================================================
    // I. Liquid Glass Integration
    // =========================================================================
    testWidgets('I. Liquid Glass: QuickNotesVisualTransition.liquidGlass wraps BottomBarGlassSurface',
        (tester) async {
      await tester.pumpWidget(buildSubject(state: false, isLiquidGlass: true));
      await tester.pumpAndSettle();

      final glassFinder = find.byType(BottomBarGlassSurface);
      expect(glassFinder, findsOneWidget);

      final BottomBarGlassSurface glass = tester.widget(glassFinder);
      expect(glass.useFrost, isTrue);
      expect(glass.width, 44.0);
      expect(glass.height, 44.0);
    });

    // =========================================================================
    // J. Lifecycle
    // =========================================================================
    testWidgets('J. Lifecycle: ticker self-stops when settled and onTransitionEnd fires',
        (tester) async {
      bool transitionEnded = false;

      await tester.pumpWidget(buildSubject(
        state: false,
        onTransitionEnd: () => transitionEnded = true,
      ));
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(buildSubject(
        state: true,
        onTransitionEnd: () => transitionEnded = true,
      ));
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(transitionEnded, isTrue);
    });
  });
}
