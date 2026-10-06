import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_content_lab_screen.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

void main() {
  Widget buildHarness() {
    return const MaterialApp(
      home: LiquidGlassMorphContentLabScreen(),
    );
  }

  group(
    'Phase 8C-B — Glass Appearance Lock, Initial/Final State & Layout Stability',
    () {
      testWidgets(
        'preserves unaltered Quick Notes BottomBarGlassSurface (sigma 3.0, 4 outer + 4 inset shadows, 0.8px border) and stable initial/final content state without permanent blur',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(buildHarness());
          await tester.pump();

          // 1. Verify Quick Notes Glass Appearance Lock
          final Finder glassFinder = find.byKey(
            const ValueKey<String>('content_lab_glass_surface'),
          );
          expect(glassFinder, findsOneWidget);
          final BottomBarGlassSurface surface =
              tester.widget<BottomBarGlassSurface>(glassFinder);
          expect(surface.useFrost, isTrue);
          expect(surface.width, closeTo(128.0, 0.01));
          expect(surface.height, closeTo(48.0, 0.01));

          // Verify BackdropFilter sigmaX=3.0, sigmaY=3.0 inside BottomBarGlassSurface
          final Finder backdropFinder = find.descendant(
            of: glassFinder,
            matching: find.byType(BackdropFilter),
          );
          expect(backdropFinder, findsOneWidget);
          final BackdropFilter backdrop =
              tester.widget<BackdropFilter>(backdropFinder);
          expect(
            backdrop.filter,
            equals(ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0)),
          );

          // Verify outer and inset DecoratedBoxes inside BottomBarGlassSurface
          final Finder decoratedBoxes = find.descendant(
            of: glassFinder,
            matching: find.byType(DecoratedBox),
          );
          expect(decoratedBoxes, findsAtLeastNWidgets(2));
          final DecoratedBox outerBox =
              tester.widget<DecoratedBox>(decoratedBoxes.first);
          final BoxDecoration outerDeco = outerBox.decoration as BoxDecoration;
          expect(outerDeco.boxShadow?.length, equals(4));

          final DecoratedBox innerBox =
              tester.widget<DecoratedBox>(decoratedBoxes.at(1));
          final inset.BoxDecoration innerDeco =
              innerBox.decoration as inset.BoxDecoration;
          expect(innerDeco.boxShadow?.length, equals(4));
          for (final BoxShadow rawShadow in innerDeco.boxShadow!) {
            expect((rawShadow as inset.BoxShadow).inset, isTrue);
          }
          final Border innerBorder = innerDeco.border! as Border;
          expect(innerBorder.top.width, closeTo(0.8, 0.001));
          final LinearGradient innerGradient =
              innerDeco.gradient! as LinearGradient;
          expect(innerGradient.colors.length, equals(4));

          // Verify zero LiquidGlassBlender or package morph widgets exist
          for (final Widget w in tester.allWidgets) {
            final String typeName = w.runtimeType.toString();
            expect(typeName.contains('LiquidGlassBlender'), isFalse);
            expect(typeName == 'LiquidGlassMorph', isFalse);
          }

          // 2. Verify Initial Content State (State A)
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateA')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateB')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('content_lab_ticker_status')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    const ValueKey<String>('content_lab_ticker_status'),
                  ),
                )
                .data,
            equals('IDLE'),
          );

          // Verify no ImageFiltered blur exists at rest
          expect(
            find.descendant(
              of: glassFinder,
              matching: find.byType(ImageFiltered),
            ),
            findsNothing,
          );

          // Record layout count before A -> B morph via RenderObject probe
          final QuickNotesRenderLayoutCountProbe initialProbeA = tester
              .renderObject<QuickNotesRenderLayoutCountProbe>(
                find.byType(QuickNotesLayoutCountProbe),
              );
          expect(initialProbeA.layoutCount, equals(1));

          // 3. Trigger A -> B and verify mid-flight & final state + ZERO per-frame relayout
          await tester.tap(
            find.byKey(const ValueKey<String>('content_action_a_to_b')),
          );
          await tester.pump();

          // Pump 10 frames (160ms, inside the overlap window t ≈ 0.355)
          for (int i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }

          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    const ValueKey<String>('content_lab_ticker_status'),
                  ),
                )
                .data,
            equals('TICKER ACTIVE'),
          );

          // Both State A (outgoing) and State B (incoming) are in tree during overlap
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateA')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateB')),
            findsOneWidget,
          );

          // Pump until settled (60 more frames)
          for (int i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }

          // Verify idle ticker shutdown, final State B, no stale State A, no permanent blur
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    const ValueKey<String>('content_lab_ticker_status'),
                  ),
                )
                .data,
            equals('IDLE'),
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateB')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateA')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: glassFinder,
              matching: find.byType(ImageFiltered),
            ),
            findsNothing,
          );

          // Verify Section 6 & 22: State A and State B each performed layout ONLY ONCE
          // across 30+ animation frames (zero per-frame text reflow / layout jitter!)
          final String settledLayoutTelemetry = tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('telemetry_layout_counts')),
              )
              .data!;
          expect(settledLayoutTelemetry, contains('Layouts A/B/C: 1/1/0'));

          // Verify ClipRRect inside BottomBarGlassSurface clips all content
          final Finder clipFinder = find.descendant(
            of: glassFinder,
            matching: find.byType(ClipRRect),
          );
          expect(clipFinder, findsOneWidget);
        },
      );
    },
  );

  group(
    'Phase 8C-B — Content Controller Unit & Matrix Verification (Timing, Overlap, Scale, Blur, Follow, Slide, Anchors)',
    () {
      const Rect rectA = Rect.fromLTWH(50, 40, 128, 48);
      const Rect rectB = Rect.fromLTWH(210, 140, 268, 176);

      test(
        'verifies Outgoing & Incoming progression, contentOutEnd, contentInStart, contentInEnd, and Overlap Window (0.25, 0.30, 0.35, 0.40, 0.50)',
        () {
          final QuickNotesMorphContentController controller =
              QuickNotesMorphContentController();
          const QuickNotesMorphContentConfig config =
              QuickNotesMorphContentConfig(
            contentOutEnd: 0.40,
            contentInStart: 0.30,
            contentInEnd: 0.80,
            oldScaleTo: 0.92,
            newScaleFrom: 0.90,
            contentBlur: 8.0,
          );

          controller.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: rectA,
          );
          controller.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: rectB,
            liveGlassRect: rectA,
            config: config,
            stiffness: 195.0,
          );

          // t = 0.00: Outgoing full (op=1, scale=1, blur=0), Incoming hidden (op=0, scale=0.90, blur=8)
          final QuickNotesMorphContentSnapshot s00 = controller.evaluateAt(
            t: 0.00,
            currentGlassRect: rectA,
            config: config,
          );
          expect(s00.outgoing, isNotNull);
          expect(s00.outgoing!.opacity, closeTo(1.0, 1e-4));
          expect(s00.outgoing!.scale, closeTo(1.0, 1e-4));
          expect(s00.outgoing!.blurSigma, closeTo(0.0, 1e-4));
          expect(s00.incoming.opacity, closeTo(0.0, 1e-4));
          expect(s00.incoming.scale, closeTo(0.90, 1e-4));
          expect(s00.incoming.blurSigma, closeTo(8.0, 1e-4));
          expect(s00.isInOverlapWindow, isFalse);

          // t = 0.25 (before contentInStart=0.30): Outgoing fading, Incoming still 0
          final QuickNotesMorphContentSnapshot s25 = controller.evaluateAt(
            t: 0.25,
            currentGlassRect: rectA,
            config: config,
          );
          expect(s25.outgoing!.opacity, greaterThan(0.40));
          expect(s25.outgoing!.opacity, lessThan(1.0));
          expect(s25.incoming.opacity, closeTo(0.0, 1e-4));
          expect(s25.isInOverlapWindow, isFalse);

          // t = 0.30 (exact contentInStart boundary): Outgoing fading, Incoming at 0.0
          final QuickNotesMorphContentSnapshot s30 = controller.evaluateAt(
            t: 0.30,
            currentGlassRect: rectA,
            config: config,
          );
          expect(s30.outgoing!.opacity, greaterThan(0.20));
          expect(s30.incoming.opacity, closeTo(0.0, 1e-4));
          expect(s30.isInOverlapWindow, isFalse);

          // t = 0.35 (inside 0.30..0.40 overlap window): BOTH outgoing and incoming visible
          final QuickNotesMorphContentSnapshot s35 = controller.evaluateAt(
            t: 0.35,
            currentGlassRect: rectA,
            config: config,
          );
          expect(s35.outgoing, isNotNull);
          expect(s35.outgoing!.opacity, greaterThan(0.05));
          expect(s35.incoming.opacity, greaterThan(0.05));
          expect(s35.isInOverlapWindow, isTrue);

          // t = 0.40 (exact contentOutEnd boundary): Outgoing reaches 0 (pruned), Incoming rising
          final QuickNotesMorphContentSnapshot s40 = controller.evaluateAt(
            t: 0.40,
            currentGlassRect: rectB,
            config: config,
          );
          expect(s40.outgoing, isNull);
          expect(s40.incoming.opacity, greaterThan(0.25));
          expect(s40.incoming.opacity, lessThan(0.50));
          expect(s40.isInOverlapWindow, isFalse);

          // t = 0.50: Outgoing gone, Incoming continuing to materialize
          final QuickNotesMorphContentSnapshot s50 = controller.evaluateAt(
            t: 0.50,
            currentGlassRect: rectB,
            config: config,
          );
          expect(s50.outgoing, isNull);
          expect(s50.incoming.opacity, greaterThan(s40.incoming.opacity));

          // t = 0.80 (exact contentInEnd): Incoming reaches opacity 1.0, scale 1.0, blur 0.0
          final QuickNotesMorphContentSnapshot s80 = controller.evaluateAt(
            t: 0.80,
            currentGlassRect: rectB,
            config: config,
          );
          expect(s80.incoming.opacity, closeTo(1.0, 1e-4));
          expect(s80.incoming.scale, closeTo(1.0, 1e-4));
          expect(s80.incoming.blurSigma, closeTo(0.0, 1e-4));
        },
      );

      test(
        'verifies oldScaleTo (1.00, 0.98, 0.95, 0.92, 0.88), newScaleFrom (1.00, 0.98, 0.95, 0.90, 0.85), and contentBlur (0, 4, 8, 12)',
        () {
          final QuickNotesMorphContentController controller =
              QuickNotesMorphContentController();
          controller.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: rectA,
          );
          controller.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: rectB,
            liveGlassRect: rectA,
            config: const QuickNotesMorphContentConfig(),
            stiffness: 195.0,
          );

          // 1. oldScaleTo matrix at t = 0.30
          const List<double> oldScales = <double>[1.00, 0.98, 0.95, 0.92, 0.88];
          double prevOutScale = 2.0;
          for (final double oldScaleTo in oldScales) {
            final QuickNotesMorphContentSnapshot snap = controller.evaluateAt(
              t: 0.30,
              currentGlassRect: rectA,
              config: QuickNotesMorphContentConfig(oldScaleTo: oldScaleTo),
            );
            final double s = snap.outgoing!.scale;
            expect(s, lessThan(prevOutScale));
            expect(s, greaterThanOrEqualTo(oldScaleTo));
            prevOutScale = s;
          }

          // 2. newScaleFrom matrix at t = 0.30 (start of incoming fade)
          const List<double> newScales = <double>[1.00, 0.98, 0.95, 0.90, 0.85];
          for (final double newScaleFrom in newScales) {
            final QuickNotesMorphContentSnapshot snapStart =
                controller.evaluateAt(
              t: 0.30,
              currentGlassRect: rectB,
              config: QuickNotesMorphContentConfig(newScaleFrom: newScaleFrom),
            );
            expect(snapStart.incoming.scale, closeTo(newScaleFrom, 1e-4));

            final QuickNotesMorphContentSnapshot snapMid =
                controller.evaluateAt(
              t: 0.55,
              currentGlassRect: rectB,
              config: QuickNotesMorphContentConfig(newScaleFrom: newScaleFrom),
            );
            expect(snapMid.incoming.scale, greaterThanOrEqualTo(newScaleFrom));
            expect(snapMid.incoming.scale, lessThanOrEqualTo(1.0));
          }

          // 3. contentBlur matrix (0, 4, 8, 12)
          const List<double> blurs = <double>[0.0, 4.0, 8.0, 12.0];
          for (final double blurVal in blurs) {
            final QuickNotesMorphContentSnapshot snap = controller.evaluateAt(
              t: 0.25,
              currentGlassRect: rectA,
              config: QuickNotesMorphContentConfig(contentBlur: blurVal),
            );
            expect(snap.incoming.blurSigma, closeTo(blurVal, 1e-4));
            if (blurVal == 0.0) {
              expect(snap.outgoing!.blurSigma, closeTo(0.0, 1e-4));
              expect(snap.incoming.isBlurActive, isFalse);
            } else {
              expect(snap.outgoing!.blurSigma, greaterThan(0.0));
              expect(snap.incoming.isBlurActive, isTrue);
            }
          }
        },
      );

      test(
        'verifies contentFollow (0.0, 0.25, 0.50, 0.75, 1.0), contentSlide (-24, -12, 0, +12, +24), zero travel vector, and anchor alignment',
        () {
          final QuickNotesMorphContentController controller =
              QuickNotesMorphContentController();
          controller.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: rectA,
          );
          controller.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: rectB,
            liveGlassRect: rectA,
            config: const QuickNotesMorphContentConfig(contentSlide: 0.0),
            stiffness: 195.0,
          );

          const Rect midGlass = Rect.fromLTWH(130, 90, 198, 112);

          // 1. contentFollow matrix (with contentSlide = 0.0)
          final List<Offset> followOffsets = <Offset>[];
          for (final double follow in const <double>[
            0.0,
            0.25,
            0.50,
            0.75,
            1.0,
          ]) {
            final QuickNotesMorphContentSnapshot snap = controller.evaluateAt(
              t: 0.30,
              currentGlassRect: midGlass,
              config: QuickNotesMorphContentConfig(
                contentFollow: follow,
                contentSlide: 0.0,
              ),
            );
            followOffsets.add(snap.incoming.localOffset);
          }

          // At follow = 0.0, incoming top-left in world space == rectB.topLeft
          expect(
            midGlass.topLeft + followOffsets.first,
             equals(rectB.topLeft),
          );
          // At follow = 1.0, incoming is centered inside midGlass
          expect(
            followOffsets.last,
            equals(
              Offset(
                (midGlass.width - rectB.width) * 0.5,
                (midGlass.height - rectB.height) * 0.5,
              ),
            ),
          );
          // Intermediate values interpolate linearly
          expect(
            followOffsets[2].dx,
            closeTo((followOffsets.first.dx + followOffsets.last.dx) * 0.5, 1e-4),
          );

          // 2. contentSlide matrix (-24, -12, 0, +12, +24) along non-zero travel vector
          final Offset travel = controller.travelUnitVector;
          expect(travel.distance, closeTo(1.0, 1e-4));
          final Offset baseNoSlide = followOffsets.first;

          for (final double slideVal in const <double>[
            -24.0,
            -12.0,
            0.0,
            12.0,
            24.0,
          ]) {
            final QuickNotesMorphContentSnapshot snap = controller.evaluateAt(
              t: 0.30, // kIn == 0.0, so full slide offset -travel * slideVal applies
              currentGlassRect: midGlass,
              config: QuickNotesMorphContentConfig(
                contentFollow: 0.0,
                contentSlide: slideVal,
              ),
            );
            final Offset delta = snap.incoming.localOffset - baseNoSlide;
            final double projectionAlongTravel =
                delta.dx * travel.dx + delta.dy * travel.dy;
            expect(projectionAlongTravel, closeTo(-slideVal, 1e-4));
          }

          // 3. Concentric / Size-Only morph: travelUnitVector == Offset.zero, contentSlide has zero effect
          final Rect concentricSmall =
              Alignment.center.inscribe(const Size(128, 48), const Rect.fromLTWH(0, 0, 520, 320));
          final Rect concentricLarge =
              Alignment.center.inscribe(const Size(268, 176), const Rect.fromLTWH(0, 0, 520, 320));
          controller.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: concentricSmall,
          );
          controller.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: concentricLarge,
            liveGlassRect: concentricSmall,
            config: const QuickNotesMorphContentConfig(contentSlide: 24.0),
            stiffness: 195.0,
          );
          expect(controller.travelUnitVector, equals(Offset.zero));
          final QuickNotesMorphContentSnapshot snapSlideNeg =
              controller.evaluateAt(
            t: 0.30,
            currentGlassRect: concentricSmall,
            config: const QuickNotesMorphContentConfig(contentSlide: -24.0),
          );
          final QuickNotesMorphContentSnapshot snapSlidePos =
              controller.evaluateAt(
            t: 0.30,
            currentGlassRect: concentricSmall,
            config: const QuickNotesMorphContentConfig(contentSlide: 24.0),
          );
          expect(
            snapSlideNeg.incoming.localOffset,
            equals(snapSlidePos.incoming.localOffset),
          );

          // 4. Anchor alignment propagation (center, topLeft, topRight, bottomLeft, bottomRight)
          for (final QuickNotesMorphAnchorOption opt
              in QuickNotesMorphAnchorOption.values) {
            final QuickNotesMorphContentSnapshot snapAnchor =
                controller.evaluateAt(
              t: 0.45,
              currentGlassRect: concentricLarge,
              config: QuickNotesMorphContentConfig(anchor: opt.alignment),
            );
            expect(snapAnchor.incoming.alignment, equals(opt.alignment));
          }
        },
      );
    },
  );

  group(
    'Phase 8C-B — Interruption (A→B→A), Retargeting (A→B→C) & Rapid Bursts (70ms, 100ms, 150ms)',
    () {
      test(
        'verifies A→B→A interruption before contentInStart never flashes B, and inside overlap window smoothly reverses A and B without opacity jumps',
        () {
          const Rect rectA = Rect.fromLTWH(50, 40, 128, 48);
          const Rect rectB = Rect.fromLTWH(210, 140, 268, 176);
          const QuickNotesMorphContentConfig config =
              QuickNotesMorphContentConfig();

          // Case 1: Interrupt A -> B -> A at t = 0.20 (BEFORE contentInStart = 0.30)
          final QuickNotesMorphContentController cEarly =
              QuickNotesMorphContentController();
          cEarly.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: rectA,
          );
          cEarly.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: rectB,
            liveGlassRect: rectA,
            config: config,
            stiffness: 195.0,
          );
          cEarly.step(cEarly.durationSeconds * 0.20, config);
          final QuickNotesMorphContentSnapshot beforeEarly =
              cEarly.currentSnapshot(currentGlassRect: rectA, config: config);
          expect(beforeEarly.incoming.opacity, closeTo(0.0, 1e-4));
          final double liveAOpacityEarly = beforeEarly.outgoing!.opacity;
          expect(liveAOpacityEarly, greaterThan(0.50));

          // Reverse to State A
          cEarly.transitionToState(
            targetState: QuickNotesMorphStateId.stateA,
            targetRect: rectA,
            liveGlassRect: rectA,
            config: config,
            stiffness: 195.0,
          );
          final QuickNotesMorphContentSnapshot afterEarly =
              cEarly.currentSnapshot(currentGlassRect: rectA, config: config);
          // B was never visible, so outgoing B is null (never flashes!)
          expect(afterEarly.outgoing, isNull);
          // A resumes from its exact live opacity (`dstFrom == liveAOpacityEarly`)
          expect(afterEarly.incoming.stateId, equals(QuickNotesMorphStateId.stateA));
          expect(afterEarly.incoming.opacity, closeTo(liveAOpacityEarly, 1e-4));

          // Case 2: Interrupt A -> B -> A at t = 0.35 (INSIDE overlap window 0.30..0.40)
          final QuickNotesMorphContentController cOverlap =
              QuickNotesMorphContentController();
          cOverlap.seedInitialState(
            stateId: QuickNotesMorphStateId.stateA,
            stateRect: rectA,
          );
          cOverlap.transitionToState(
            targetState: QuickNotesMorphStateId.stateB,
            targetRect: rectB,
            liveGlassRect: rectA,
            config: config,
            stiffness: 195.0,
          );
          for (int i = 0; i < 10; i++) {
            cOverlap.step(cOverlap.durationSeconds * 0.035, config);
          }
          final QuickNotesMorphContentSnapshot beforeOverlap =
              cOverlap.currentSnapshot(currentGlassRect: rectA, config: config);
          final double aOpBefore = beforeOverlap.outgoing!.opacity;
          final double bOpBefore = beforeOverlap.incoming.opacity;
          expect(aOpBefore, greaterThan(0.05));
          expect(bOpBefore, greaterThan(0.05));

          cOverlap.transitionToState(
            targetState: QuickNotesMorphStateId.stateA,
            targetRect: rectA,
            liveGlassRect: rectA,
            config: config,
            stiffness: 195.0,
          );
          final QuickNotesMorphContentSnapshot afterOverlap =
              cOverlap.currentSnapshot(currentGlassRect: rectA, config: config);
          expect(afterOverlap.incoming.stateId, equals(QuickNotesMorphStateId.stateA));
          expect(afterOverlap.incoming.opacity, closeTo(aOpBefore, 1e-4));
          expect(afterOverlap.outgoing!.stateId, equals(QuickNotesMorphStateId.stateB));
          expect(afterOverlap.outgoing!.opacity, closeTo(bOpBefore, 1e-4));
        },
      );

      testWidgets(
        'executes widget-level A→B→A interruption, A→B→C retargeting, Overlap Inspector buttons, and Rapid 70ms/100ms/150ms bursts cleanly',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(buildHarness());
          await tester.pump();

          // 1. Test Overlap Inspector buttons (0.25, 0.30, 0.35, 0.40, 0.50)
          await tester.tap(
            find.byKey(const ValueKey<String>('content_overlap_t_0.35')),
          );
          await tester.pump();
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey<String>('telemetry_overlap_status')),
                )
                .data,
            equals('Overlap: YES'),
          );

          await tester.tap(
            find.byKey(const ValueKey<String>('content_overlap_t_0.50')),
          );
          await tester.pump();
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey<String>('telemetry_overlap_status')),
                )
                .data,
            equals('Overlap: NO'),
          );

          // 2. Test A -> B -> A Interruption button
          await tester.tap(
            find.byKey(const ValueKey<String>('content_action_interrupt_aba')),
          );
          await tester.pump();
          for (int i = 0; i < 65; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateA')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateB')),
            findsNothing,
          );

          // 3. Test A -> B -> C Retargeting button
          await tester.tap(
            find.byKey(const ValueKey<String>('content_action_retarget_abc')),
          );
          await tester.pump();
          for (int i = 0; i < 70; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateC')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateA')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_content_text_stateB')),
            findsNothing,
          );

          // 4. Test Rapid 70ms, 100ms, and 150ms bursts
          for (final String keyName in const <String>[
            'content_action_rapid_70',
            'content_action_rapid_100',
            'content_action_rapid_150',
          ]) {
            await tester.tap(find.byKey(ValueKey<String>(keyName)));
            await tester.pump();
            for (int i = 0; i < 95; i++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(tester.takeException(), isNull);
            expect(
              tester
                  .widget<Text>(
                    find.byKey(
                      const ValueKey<String>('content_lab_ticker_status'),
                    ),
                  )
                  .data,
              equals('IDLE'),
            );
            expect(
              find.byKey(const ValueKey<String>('morph_content_text_stateA')),
              findsOneWidget,
            );
          }
        },
      );
    },
  );
}
