import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_reference_lab_screen.dart';

void main() {
  setUp(() {
    LiquidGlassEngine.liteGlassOnSkia = false;
    LiquidGlassEngine.liteGlassOnImpeller = false;
  });

  tearDown(() {
    LiquidGlassEngine.liteGlassOnSkia = false;
    LiquidGlassEngine.liteGlassOnImpeller = false;
  });

  Widget buildHarness({Size size = const Size(1280, 1600)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: const MaterialApp(
        home: LiquidGlassMorphReferenceLabScreen(),
      ),
    );
  }

  LiquidGlassMorph readNativeMorph(WidgetTester tester) {
    return tester.widget<LiquidGlassMorph>(
      find.byKey(const ValueKey<String>('native_liquid_glass_morph')),
    );
  }

  /// Reads the positioned rects of the lenses rendered inside LiquidGlassMorph.
  /// When blended=true, returns `[dstRectShifted, srcRectShifted]`.
  /// When blended=false (or liteGlass=true), returns `[dstRect]`.
  List<Rect> readLensPositionedRects(WidgetTester tester) {
    final Finder morphFinder = find.byKey(
      const ValueKey<String>('native_liquid_glass_morph'),
    );
    final Finder lenses = find.descendant(
      of: morphFinder,
      matching: find.byType(LiquidGlassLens),
    );
    final List<Rect> rects = <Rect>[];
    final int count = lenses.evaluate().length;
    for (int i = 0; i < count; i++) {
      final Finder lensFinder = lenses.at(i);
      final Finder parentPositioned = find.ancestor(
        of: lensFinder,
        matching: find.byType(Positioned),
      );
      final Positioned pos = tester.widget<Positioned>(
        parentPositioned.first,
      );
      rects.add(
        Rect.fromLTWH(
          pos.left ?? 0,
          pos.top ?? 0,
          pos.width ?? 0,
          pos.height ?? 0,
        ),
      );
    }
    return rects;
  }

  group('Phase 8B — Native Morph Reference Lab Screen Construction & Baseline', () {
    testWidgets(
      'mounts native LiquidGlassMorph directly with default fluid baseline in State A',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        // First pump after mount delivers _RenderMorphMeasure post-frame measurement.
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('native_liquid_glass_morph')),
          findsOneWidget,
        );
        expect(find.byType(LiquidGlassMorph), findsOneWidget);
        expect(find.byType(LiquidGlassBlender), findsOneWidget);
        expect(find.byType(LiquidGlassLens), findsNWidgets(2));

        final LiquidGlassMorph morph = readNativeMorph(tester);
        expect(morph.motion.stiffness, LiquidGlassMorphMotion.fluid.stiffness);
        expect(morph.motion.damping, LiquidGlassMorphMotion.fluid.damping);
        expect(morph.motion.stretch, LiquidGlassMorphMotion.fluid.stretch);
        expect(morph.motion.blended, isTrue);
        expect(morph.motion.anchor, Alignment.center);
        expect(
          morph.motion.advanced.leadBounce,
          LiquidGlassMorphMotion.fluid.advanced.leadBounce,
        );
        expect(
          morph.motion.advanced.followDelay,
          LiquidGlassMorphMotion.fluid.advanced.followDelay,
        );
        expect(
          morph.motion.advanced.seedScale,
          LiquidGlassMorphMotion.fluid.advanced.seedScale,
        );
        expect(
          morph.motion.advanced.contentFollow,
          LiquidGlassMorphMotion.fluid.advanced.contentFollow,
        );
        expect(
          morph.motion.advanced.contentSlide,
          LiquidGlassMorphMotion.fluid.advanced.contentSlide,
        );
        expect(
          morph.motion.advanced.contentBlur,
          LiquidGlassMorphMotion.fluid.advanced.contentBlur,
        );

        final List<Rect> rects = readLensPositionedRects(tester);
        expect(rects.length, 2);
        // At rest after initial seed, both dst and src rects are 128x48.
        expect(rects[0].width, closeTo(128.0, 0.1));
        expect(rects[0].height, closeTo(48.0, 0.1));
        expect(rects[1].width, closeTo(128.0, 0.1));
        expect(rects[1].height, closeTo(48.0, 0.1));
      },
    );

    testWidgets(
      'selects all 5 official 4.3.1 presets and applies exact native parameters',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        Future<void> selectAndVerify(
          MorphReferencePreset preset,
          LiquidGlassMorphMotion expected,
        ) async {
          await tester.tap(
            find.byKey(ValueKey<String>('preset_chip_${preset.name}')),
          );
          await tester.pump();

          final LiquidGlassMorph morph = readNativeMorph(tester);
          expect(morph.motion.stiffness, expected.stiffness);
          expect(morph.motion.damping, expected.damping);
          expect(morph.motion.stretch, expected.stretch);
          expect(morph.motion.blended, expected.blended);
          expect(morph.motion.anchor, expected.anchor);
          expect(morph.motion.advanced.leadBounce, expected.advanced.leadBounce);
          expect(
            morph.motion.advanced.followDelay,
            expected.advanced.followDelay,
          );
          expect(morph.motion.advanced.seedScale, expected.advanced.seedScale);
          expect(morph.motion.advanced.linger, expected.advanced.linger);
          expect(morph.motion.advanced.drainSpeed, expected.advanced.drainSpeed);
          expect(
            morph.motion.advanced.drainInward,
            expected.advanced.drainInward,
          );
          expect(
            morph.motion.advanced.sourceFollows,
            expected.advanced.sourceFollows,
          );
          expect(morph.motion.advanced.neckRamp, expected.advanced.neckRamp);
          expect(
            morph.motion.advanced.contentFollow,
            expected.advanced.contentFollow,
          );
          expect(
            morph.motion.advanced.contentSlide,
            expected.advanced.contentSlide,
          );
          expect(
            morph.motion.advanced.contentBlur,
            expected.advanced.contentBlur,
          );
        }

        await selectAndVerify(
          MorphReferencePreset.anchoredPop,
          LiquidGlassMorphMotion.anchoredPop,
        );
        await selectAndVerify(
          MorphReferencePreset.plain,
          LiquidGlassMorphMotion.plain,
        );
        // Verify plain preset removes LiquidGlassBlender and uses 1 LiquidGlassLens.
        expect(find.byType(LiquidGlassBlender), findsNothing);
        expect(find.byType(LiquidGlassLens), findsOneWidget);

        await selectAndVerify(
          MorphReferencePreset.droplet,
          LiquidGlassMorphMotion.droplet,
        );
        expect(find.byType(LiquidGlassBlender), findsOneWidget);
        expect(find.byType(LiquidGlassLens), findsNWidgets(2));

        await selectAndVerify(
          MorphReferencePreset.calm,
          LiquidGlassMorphMotion.calm,
        );
        await selectAndVerify(
          MorphReferencePreset.fluid,
          LiquidGlassMorphMotion.fluid,
        );
      },
    );
  });

  group('Phase 8B — Blended vs Unblended & Lite Glass Runtime Experiments', () {
    testWidgets(
      'toggling Blended OFF switches native LiquidGlassMorph from 2-blob LiquidGlassBlender to 1-lens mode',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        expect(find.byType(LiquidGlassBlender), findsOneWidget);
        expect(find.byType(LiquidGlassLens), findsNWidgets(2));

        await tester.tap(find.byKey(const ValueKey<String>('toggle_blended')));
        await tester.pump();

        final LiquidGlassMorph morph = readNativeMorph(tester);
        expect(morph.motion.blended, isFalse);
        expect(find.byType(LiquidGlassBlender), findsNothing);
        expect(find.byType(LiquidGlassLens), findsOneWidget);
      },
    );

    testWidgets(
      'enabling Lite Glass forces native LiquidGlassMorph into single-lens unblended path even when motion.blended is true',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // BEFORE Lite Glass: fluid preset has motion.blended == true and renders LiquidGlassBlender.
        expect(readNativeMorph(tester).motion.blended, isTrue);
        expect(find.byType(LiquidGlassBlender), findsOneWidget);
        expect(find.byType(LiquidGlassLens), findsNWidgets(2));

        // Enable Lite Glass.
        await tester.tap(
          find.byKey(const ValueKey<String>('toggle_lite_glass')),
        );
        await tester.pump();

        // AFTER Lite Glass: widget.motion.blended is still true on the input object,
        // but LiquidGlassMorph._m forces blended: false and neckRamp: 0 internally!
        expect(LiquidGlassEngine.liteGlass, isTrue);
        expect(readNativeMorph(tester).motion.blended, isTrue);
        expect(find.byType(LiquidGlassBlender), findsNothing);
        expect(find.byType(LiquidGlassLens), findsOneWidget);
      },
    );
  });

  group('Phase 8B — Growing (A→B), Shrinking (B→A), Interruption & Retargeting', () {
    testWidgets(
      'Growing morph (A→B) seeds destination at seedScale (1.0 in fluid, 0.55 in droplet) and leads position ahead of size',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        final List<Rect> initialRects = readLensPositionedRects(tester);
        final Rect initialDst = initialRects[0];
        expect(initialDst.width, closeTo(128.0, 0.1));
        expect(initialDst.height, closeTo(48.0, 0.1));

        // Trigger A -> B under default fluid (seedScale = 1.0, followDelay = 0.04s)
        await tester.tap(find.byKey(const ValueKey<String>('action_a_to_b')));
        await tester.pump(); // schedules measurement of State B
        await tester.pump(); // _onMeasured fires _retarget(swap: true)

        final List<Rect> seededRects = readLensPositionedRects(tester);
        final Rect seededDst = seededRects[0];
        final Rect seededSrc = seededRects[1];

        // At frame 0 of fluid morph: _dst is seeded at from.size * 1.0 = 128x48
        expect(seededDst.width, closeTo(128.0, 0.5));
        expect(seededDst.height, closeTo(48.0, 0.5));
        expect(seededSrc.width, closeTo(128.0, 0.5));
        expect(seededSrc.height, closeTo(48.0, 0.5));

        // Advance 32ms (within followDelay = 40ms for fluid):
        // Position (cx, cy) leaps ahead immediately while w, h hold at 128x48 during followDelay!
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final List<Rect> earlyRects = readLensPositionedRects(tester);
        final Rect earlyDst = earlyRects[0];
        expect(
          (earlyDst.center - seededDst.center).distance,
          greaterThan(5.0),
        );
        expect(earlyDst.width, closeTo(128.0, 0.5));
        expect(earlyDst.height, closeTo(48.0, 0.5));

        // Advance to settle.
        for (int i = 0; i < 45; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final List<Rect> settledRects = readLensPositionedRects(tester);
        expect(settledRects[0].width, closeTo(268.0, 0.5));
        expect(settledRects[0].height, closeTo(176.0, 0.5));

        // Reset to A, select droplet preset (seedScale = 0.55), and trigger A -> B
        await tester.tap(find.byKey(const ValueKey<String>('action_reset')));
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('preset_chip_droplet')),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey<String>('action_a_to_b')));
        await tester.pump();
        await tester.pump();

        final List<Rect> dropletSeeded = readLensPositionedRects(tester);
        expect(dropletSeeded[0].width, closeTo(128.0 * 0.55, 0.5));
        expect(dropletSeeded[0].height, closeTo(48.0 * 0.55, 0.5));
      },
    );

    testWidgets(
      'Shrinking morph (B→A) leads size collapse ahead of position and snaps both blobs to target on settle',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // Move to B and let settle.
        await tester.tap(find.byKey(const ValueKey<String>('action_a_to_b')));
        await tester.pump();
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(readLensPositionedRects(tester)[0].width, closeTo(268.0, 0.5));

        // Trigger B -> A (Shrinking)
        await tester.tap(find.byKey(const ValueKey<String>('action_b_to_a')));
        await tester.pump(); // measurement scheduled
        await tester.pump(); // _retarget(swap: true) fires

        // On shrinking in blended mode (fluid seedScale=1.0), _dst snaps its position/size
        // to `to` (128x48), while _src holds the 268x176 card and collapses/travels toward `to`.
        final List<Rect> startShrinkRects = readLensPositionedRects(tester);
        final Rect dstAtShrinkStart = startShrinkRects[0];
        final Rect srcAtShrinkStart = startShrinkRects[1];
        expect(dstAtShrinkStart.width, closeTo(128.0, 0.5));
        expect(dstAtShrinkStart.height, closeTo(48.0, 0.5));
        expect(srcAtShrinkStart.width, closeTo(268.0, 0.5));
        expect(srcAtShrinkStart.height, closeTo(176.0, 0.5));

        // Advance 48ms: _src size collapses rapidly toward 128x48 ahead of its delayed anchor.
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        final Rect srcMidShrink = readLensPositionedRects(tester)[1];
        expect(srcMidShrink.width, lessThan(268.0));
        expect(srcMidShrink.height, lessThan(176.0));

        // Settle completely: both _dst and _src coincide on _target (128x48).
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final List<Rect> settledShrinkRects = readLensPositionedRects(tester);
        expect(settledShrinkRects[0].width, closeTo(128.0, 0.5));
        expect(settledShrinkRects[0].height, closeTo(48.0, 0.5));
        expect(settledShrinkRects[1].width, closeTo(128.0, 0.5));
        expect(settledShrinkRects[1].height, closeTo(48.0, 0.5));
      },
    );

    testWidgets(
      'Interruption (A→B→A) and Retargeting (A→B→C) continue from live mid-flight geometry without snapping',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // Trigger A -> B -> A interruption action
        await tester.tap(
          find.byKey(const ValueKey<String>('action_interrupt_aba')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 60));

        final Rect midFlightBeforeInterrupt = readLensPositionedRects(tester)[0];
        expect(midFlightBeforeInterrupt.width, greaterThan(110.0));
        expect(midFlightBeforeInterrupt.width, lessThan(268.0));

        // Advance past the 120ms timer when B -> A fires
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump();

        // Settle back to State A (128x48)
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(readLensPositionedRects(tester)[0].width, closeTo(128.0, 0.5));
        expect(readLensPositionedRects(tester)[0].height, closeTo(48.0, 0.5));

        // Trigger A -> B -> C retargeting action
        await tester.tap(
          find.byKey(const ValueKey<String>('action_retarget_abc')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        await tester.pump(const Duration(milliseconds: 70));
        await tester.pump();

        // Let C settle (216x96)
        for (int i = 0; i < 55; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(readLensPositionedRects(tester)[0].width, closeTo(216.0, 0.5));
        expect(readLensPositionedRects(tester)[0].height, closeTo(96.0, 0.5));
      },
    );

    testWidgets(
      'Rapid burst (A→B→A→B→A) and Reset complete cleanly without framework or shader exceptions',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('action_rapid_burst')),
        );
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        expect(readLensPositionedRects(tester)[0].width, closeTo(128.0, 0.5));

        // Change preset to droplet, then click RESET
        await tester.tap(
          find.byKey(const ValueKey<String>('preset_chip_droplet')),
        );
        await tester.pump();
        expect(
          readNativeMorph(tester).motion.stiffness,
          LiquidGlassMorphMotion.droplet.stiffness,
        );

        await tester.tap(find.byKey(const ValueKey<String>('action_reset')));
        await tester.pump();
        expect(
          readNativeMorph(tester).motion.stiffness,
          LiquidGlassMorphMotion.fluid.stiffness,
        );
      },
    );
  });

  group('Phase 8B — Anchors, Topology Modes, Shapes & Parameter Sliders', () {
    testWidgets(
      'Anchor options, Topology modes (sizeOnly, positionOnly, sizeAndPosition), Shape options, and Sliders update native LiquidGlassMorph',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // Test Anchor topLeft
        await tester.tap(
          find.byKey(const ValueKey<String>('anchor_chip_topLeft')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).motion.anchor, Alignment.topLeft);
        expect(readNativeMorph(tester).alignment, Alignment.topLeft);

        // Test Topology: sizeOnly
        await tester.tap(
          find.byKey(const ValueKey<String>('topology_chip_sizeOnly')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).width, isNull);
        expect(readNativeMorph(tester).height, isNull);

        // Test Topology: positionOnly (sets explicit 156x56 override)
        await tester.tap(
          find.byKey(const ValueKey<String>('topology_chip_positionOnly')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).width, 156.0);
        expect(readNativeMorph(tester).height, 56.0);

        // Test Shape: capsuleAuto (shape == null) vs rounded16 vs superellipse28
        await tester.tap(
          find.byKey(const ValueKey<String>('shape_chip_capsuleAuto')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).style.shape, isNull);

        await tester.tap(
          find.byKey(const ValueKey<String>('shape_chip_rounded16')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).style.shape?.cornerRadius, 16.0);
        expect(
          readNativeMorph(tester).style.shape?.cornerStyle,
          LiquidGlassCornerStyle.roundedRectangle,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('shape_chip_superellipse28')),
        );
        await tester.pump();
        expect(readNativeMorph(tester).style.shape?.cornerRadius, 28.0);
        expect(
          readNativeMorph(tester).style.shape?.cornerStyle,
          LiquidGlassCornerStyle.continuousRoundedRectangle,
        );

        // Exercise sliders
        final Slider stretchSlider = tester.widget<Slider>(
          find.byKey(const ValueKey<String>('slider_stretch')),
        );
        stretchSlider.onChanged!(0.75);
        await tester.pump();
        expect(readNativeMorph(tester).motion.stretch, closeTo(0.75, 0.001));

        final Slider contentBlurSlider = tester.widget<Slider>(
          find.byKey(const ValueKey<String>('slider_content_blur')),
        );
        contentBlurSlider.onChanged!(8.0);
        await tester.pump();
        expect(
          readNativeMorph(tester).motion.advanced.contentBlur,
          closeTo(8.0, 0.001),
        );
      },
    );
  });
}
