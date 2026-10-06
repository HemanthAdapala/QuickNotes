import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassBlender;
import 'package:quick_notes/themes/glassmorphism_presets.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart'
    show BottomBarGlassSurface;

void main() {
  Widget buildHarness({Size size = const Size(1280, 1600)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: const MaterialApp(
        home: LiquidGlassMorphMechanicsLabScreen(),
      ),
    );
  }

  Rect readGlassSurfaceRect(WidgetTester tester) {
    final Positioned pos = tester.widget<Positioned>(
      find.byKey(const ValueKey<String>('mechanics_positioned_glass_host')),
    );
    return Rect.fromLTWH(
      pos.left ?? 0.0,
      pos.top ?? 0.0,
      pos.width ?? 0.0,
      pos.height ?? 0.0,
    );
  }

  BottomBarGlassSurface readGlassSurface(WidgetTester tester) {
    return tester.widget<BottomBarGlassSurface>(
      find.byKey(const ValueKey<String>('mechanics_quick_notes_glass_surface')),
    );
  }

  group('Phase 8C-A — Existing Glass Appearance Lock & Initial/Target Geometry', () {
    testWidgets(
      'uses unaltered Quick Notes BottomBarGlassSurface with locked GlassmorphismPresets and zero LiquidGlassBlender',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // Verify Quick Notes existing glass surface is used directly and no LiquidGlassBlender exists.
        expect(find.byType(BottomBarGlassSurface), findsOneWidget);
        expect(find.byType(LiquidGlassBlender), findsNothing);
        expect(GlassmorphismPresets.blurSigma, 3.0);
        expect(GlassmorphismPresets.fillColor, Colors.transparent);
        expect(GlassmorphismPresets.shadows.length, 4);
        expect(GlassmorphismPresets.innerShadows.length, 4);

        // Verify initial State A geometry (128x48)
        final Rect initialRect = readGlassSurfaceRect(tester);
        final BottomBarGlassSurface surface = readGlassSurface(tester);
        expect(initialRect.width, closeTo(128.0, 0.01));
        expect(initialRect.height, closeTo(48.0, 0.01));
        expect(surface.width, closeTo(128.0, 0.01));
        expect(surface.height, closeTo(48.0, 0.01));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('mechanics_lab_status_badge')),
              )
              .data,
          'IDLE',
        );
      },
    );
  });

  group('Phase 8C-A — 4D Controller Unit & Matrix Verification (Stretch, LeadBounce, FollowDelay, Anchors)', () {
    test(
      'verifies Growing (Small→Large) vs Shrinking (Large→Small) asymmetric lead-follow and followDelay (0ms, 40ms, 100ms, 150ms)',
      () {
        const Rect rectA = Rect.fromLTWH(40, 40, 128, 48);
        const Rect rectB = Rect.fromLTWH(200, 120, 268, 176);

        for (final double delaySec in <double>[0.0, 0.04, 0.10, 0.15]) {
          final QuickNotesMorphGeometryController ctrl =
              QuickNotesMorphGeometryController(initialRect: rectA);
          final QuickNotesMorphGeometryConfig config =
              QuickNotesMorphGeometryConfig(
            stiffness: 195.0,
            damping: 19.5,
            stretch: 0.60,
            leadBounce: 0.10,
            followDelaySeconds: delaySec,
            anchor: Alignment.center,
          );

          // GROWING: A -> B
          ctrl.transitionToRect(rectB, config: config);
          expect(ctrl.isGrowing, isTrue);
          expect(ctrl.sizeHoldRemaining, closeTo(delaySec, 1e-6));
          expect(ctrl.anchorHoldRemaining, 0.0);

          if (delaySec > 0.0) {
            // Step half of the followDelay: position MUST move, size MUST hold at 128x48
            ctrl.step(delaySec * 0.5, config);
            expect(
              (ctrl.currentRect.center - rectA.center).distance,
              greaterThan(1.0),
            );
            expect(ctrl.currentRect.width, closeTo(128.0, 1e-4));
            expect(ctrl.currentRect.height, closeTo(48.0, 1e-4));
          }

          // Step until settled
          int steps = 0;
          while (ctrl.isAnimating && steps < 300) {
            ctrl.step(1.0 / 60.0, config);
            expect(ctrl.currentRect.width, greaterThan(0.0));
            expect(ctrl.currentRect.height, greaterThan(0.0));
            expect(ctrl.currentRect.left.isFinite, isTrue);
            expect(ctrl.currentRect.top.isFinite, isTrue);
            steps++;
          }
          expect(ctrl.isAnimating, isFalse);
          expect(ctrl.currentRect.width, closeTo(rectB.width, 0.01));
          expect(ctrl.currentRect.height, closeTo(rectB.height, 0.01));
          expect(ctrl.currentRect.center.dx, closeTo(rectB.center.dx, 0.01));
          expect(ctrl.currentRect.center.dy, closeTo(rectB.center.dy, 0.01));

          // SHRINKING: B -> A
          ctrl.transitionToRect(rectB, config: config);
          ctrl.seedInitialRect(rectB);
          ctrl.transitionToRect(rectA, config: config);
          expect(ctrl.isGrowing, isFalse);
          expect(ctrl.anchorHoldRemaining, closeTo(delaySec, 1e-6));
          expect(ctrl.sizeHoldRemaining, 0.0);

          if (delaySec > 0.0) {
            // Step half of the followDelay: size MUST collapse first, center MUST hold at rectB.center
            ctrl.step(delaySec * 0.5, config);
            expect(ctrl.currentRect.width, lessThan(rectB.width - 1.0));
            expect(ctrl.currentRect.height, lessThan(rectB.height - 1.0));
            expect(ctrl.currentRect.center.dx, closeTo(rectB.center.dx, 1e-4));
            expect(ctrl.currentRect.center.dy, closeTo(rectB.center.dy, 1e-4));
          }
        }
      },
    );

    test(
      'verifies stretch (0.0, 0.25, 0.50, 0.75, 1.0) increases leading displacement rate monotonically',
      () {
        const Rect rectA = Rect.fromLTWH(20, 20, 128, 48);
        const Rect rectB = Rect.fromLTWH(220, 140, 268, 176);
        final List<double> stretches = <double>[0.0, 0.25, 0.50, 0.75, 1.0];
        double previousEarlyTravel = -1.0;

        for (final double s in stretches) {
          final QuickNotesMorphGeometryController ctrl =
              QuickNotesMorphGeometryController(initialRect: rectA);
          final QuickNotesMorphGeometryConfig config =
              QuickNotesMorphGeometryConfig(
            stretch: s,
            leadBounce: 0.10,
            followDelaySeconds: 0.04,
          );
          expect(config.leadMultiplier, closeTo(1.0 + 2.2 * s, 1e-6));

          ctrl.transitionToRect(rectB, config: config);
          // Step 3 frames (48ms)
          for (int i = 0; i < 3; i++) {
            ctrl.step(0.016, config);
          }
          final double travel =
              (ctrl.currentRect.center - rectA.center).distance;
          expect(travel, greaterThan(previousEarlyTravel));
          previousEarlyTravel = travel;
        }
      },
    );

    test(
      'verifies leadBounce (0.0, 0.10, 0.25) increases peak positional overshoot monotonically',
      () {
        const Rect rectA = Rect.fromLTWH(20, 20, 128, 48);
        const Rect rectB = Rect.fromLTWH(220, 20, 268, 176);
        final List<double> bounces = <double>[0.0, 0.10, 0.25];
        double previousPeakX = -1.0;

        for (final double lb in bounces) {
          final QuickNotesMorphGeometryController ctrl =
              QuickNotesMorphGeometryController(initialRect: rectA);
          final QuickNotesMorphGeometryConfig config =
              QuickNotesMorphGeometryConfig(
            stretch: 0.60,
            leadBounce: lb,
            followDelaySeconds: 0.04,
          );

          ctrl.transitionToRect(rectB, config: config);
          double maxCenterX = rectA.center.dx;
          for (int i = 0; i < 120; i++) {
            ctrl.step(1.0 / 60.0, config);
            if (ctrl.currentRect.center.dx > maxCenterX) {
              maxCenterX = ctrl.currentRect.center.dx;
            }
          }
          expect(maxCenterX, greaterThan(previousPeakX));
          previousPeakX = maxCenterX;
        }
      },
    );

    test(
      'verifies Anchor preservation for center, topLeft, topRight, bottomLeft, and bottomRight during Small→Large',
      () {
        const Size field = Size(500, 320);
        final List<Alignment> anchors = <Alignment>[
          Alignment.center,
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ];

        for (final Alignment a in anchors) {
          final Rect from = a.inscribe(const Size(128, 48), Offset.zero & field);
          final Rect to = a.inscribe(const Size(268, 176), Offset.zero & field);
          final Offset expectedPinnedPoint = a.withinRect(from);

          final QuickNotesMorphGeometryController ctrl =
              QuickNotesMorphGeometryController(
            initialRect: from,
            initialAnchor: a,
          );
          final QuickNotesMorphGeometryConfig config =
              QuickNotesMorphGeometryConfig(
            anchor: a,
            stretch: 0.60,
            leadBounce: 0.10,
            followDelaySeconds: 0.04,
          );

          ctrl.transitionToRect(to, config: config);
          for (int i = 0; i < 60; i++) {
            ctrl.step(1.0 / 60.0, config);
            final Offset liveAnchorPoint = a.withinRect(ctrl.currentRect);
            expect(
              liveAnchorPoint.dx,
              closeTo(expectedPinnedPoint.dx, 1e-4),
              reason: 'Anchor $a X drifted on frame $i',
            );
            expect(
              liveAnchorPoint.dy,
              closeTo(expectedPinnedPoint.dy, 1e-4),
              reason: 'Anchor $a Y drifted on frame $i',
            );
          }
        }
      },
    );
  });

  group('Phase 8C-A — Widget Lab Transitions, Interruptions, Retargeting & Rapid Bursts', () {
    testWidgets(
      'executes Growing (A→B) and Shrinking (B→A) on Quick Notes BottomBarGlassSurface and stops ticker when idle',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        final Rect startRect = readGlassSurfaceRect(tester);
        expect(startRect.width, closeTo(128.0, 0.1));
        expect(startRect.height, closeTo(48.0, 0.1));

        // Trigger A -> B (Growing)
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_a_to_b')),
        );
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('mechanics_lab_status_badge')),
              )
              .data,
          'MOVING',
        );

        // Pump 32ms (within 40ms followDelay): center moves first, size holds at 128x48!
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final Rect earlyGrowRect = readGlassSurfaceRect(tester);
        expect(
          (earlyGrowRect.center - startRect.center).distance,
          greaterThan(5.0),
        );
        expect(earlyGrowRect.width, closeTo(128.0, 0.1));
        expect(earlyGrowRect.height, closeTo(48.0, 0.1));

        // Pump to settle
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final Rect settledBRect = readGlassSurfaceRect(tester);
        expect(settledBRect.width, closeTo(268.0, 0.1));
        expect(settledBRect.height, closeTo(176.0, 0.1));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('mechanics_lab_status_badge')),
              )
              .data,
          'IDLE',
        );

        // Trigger B -> A (Shrinking)
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_b_to_a')),
        );
        await tester.pump();

        // Pump 32ms (within 40ms followDelay): size collapses first, center holds at State B!
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final Rect earlyShrinkRect = readGlassSurfaceRect(tester);
        expect(earlyShrinkRect.width, lessThan(260.0));
        expect(earlyShrinkRect.height, lessThan(170.0));
        expect(
          (earlyShrinkRect.center - settledBRect.center).distance,
          lessThan(0.1),
        );

        // Pump to settle back at A
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final Rect settledARect = readGlassSurfaceRect(tester);
        expect(settledARect.width, closeTo(128.0, 0.1));
        expect(settledARect.height, closeTo(48.0, 0.1));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('mechanics_lab_status_badge')),
              )
              .data,
          'IDLE',
        );
      },
    );

    testWidgets(
      'executes Position-Only (156×56) and Size-Only (concentric) transitions accurately',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // Select Position Only mode
        await tester.tap(
          find.byKey(
            const ValueKey<String>('mechanics_topology_positionOnly'),
          ),
        );
        await tester.pump();
        final Rect posOnlyStart = readGlassSurfaceRect(tester);
        expect(posOnlyStart.width, closeTo(156.0, 0.1));
        expect(posOnlyStart.height, closeTo(56.0, 0.1));

        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_a_to_b')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        final Rect posOnlyMid = readGlassSurfaceRect(tester);
        expect(posOnlyMid.width, closeTo(156.0, 0.1));
        expect(posOnlyMid.height, closeTo(56.0, 0.1));
        expect(
          (posOnlyMid.center - posOnlyStart.center).distance,
          greaterThan(20.0),
        );

        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        // Select Size Only mode (concentric around Center)
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_topology_sizeOnly')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_b_to_a')),
        );
        await tester.pump();
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        final Rect sizeOnlyStart = readGlassSurfaceRect(tester);
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_a_to_b')),
        );
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final Rect sizeOnlyMid = readGlassSurfaceRect(tester);
        expect(
          (sizeOnlyMid.center - sizeOnlyStart.center).distance,
          lessThan(0.01),
        );
        expect(sizeOnlyMid.width, greaterThan(128.0));
      },
    );

    testWidgets(
      'executes Interruption (A→B→A), Retargeting (A→B→C), and Rapid 70ms/100ms bursts without geometry snaps or NaN values',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // 1. Interruption A -> B -> A
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_interrupt_aba')),
        );
        await tester.pump();
        for (int i = 0; i < 7; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // 112ms
        }
        final Rect beforeInterrupt = readGlassSurfaceRect(tester);
        expect(beforeInterrupt.width, greaterThan(140.0));
        expect(beforeInterrupt.width, lessThan(268.0));

        // Advance past 120ms timer when reversal B -> A triggers
        await tester.pump(const Duration(milliseconds: 16)); // 128ms
        final Rect immediatelyAfterInterrupt = readGlassSurfaceRect(tester);
        // Must not snap back to 128x48 on the reversal frame
        expect(
          (immediatelyAfterInterrupt.width - beforeInterrupt.width).abs(),
          lessThan(30.0),
        );

        for (int i = 0; i < 70; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(readGlassSurfaceRect(tester).width, closeTo(128.0, 0.1));
        expect(readGlassSurfaceRect(tester).height, closeTo(48.0, 0.1));

        // 2. Retargeting A -> B -> C
        await tester.tap(
          find.byKey(const ValueKey<String>('mechanics_action_retarget_abc')),
        );
        await tester.pump();
        for (int i = 0; i < 7; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // 112ms
        }
        final Rect beforeRetarget = readGlassSurfaceRect(tester);
        await tester.pump(const Duration(milliseconds: 16)); // 128ms (C fires)
        final Rect immediatelyAfterRetarget = readGlassSurfaceRect(tester);
        // Must continue from intermediate state without snapping to B (268x176)
        expect(
          (immediatelyAfterRetarget.center - beforeRetarget.center).distance,
          lessThan(35.0),
        );

        for (int i = 0; i < 70; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(readGlassSurfaceRect(tester).width, closeTo(216.0, 0.1));
        expect(readGlassSurfaceRect(tester).height, closeTo(96.0, 0.1));

        // 3. Rapid 70ms and 100ms bursts
        for (final String keyName in <String>[
          'mechanics_action_rapid_70ms',
          'mechanics_action_rapid_100ms',
        ]) {
          await tester.tap(find.byKey(ValueKey<String>(keyName)));
          await tester.pump();
          for (int i = 0; i < 85; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            final Rect r = readGlassSurfaceRect(tester);
            expect(r.width, greaterThanOrEqualTo(1.0));
            expect(r.height, greaterThanOrEqualTo(1.0));
            expect(r.left.isFinite, isTrue);
            expect(r.top.isFinite, isTrue);
          }
          expect(tester.takeException(), isNull);
          expect(readGlassSurfaceRect(tester).width, closeTo(128.0, 0.1));
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    const ValueKey<String>('mechanics_lab_status_badge'),
                  ),
                )
                .data,
            'IDLE',
          );
        }
      },
    );
  });
}
