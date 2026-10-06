import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/morph_content_controller.dart';
import 'package:quick_notes/core/motion/morph_geometry_config.dart';
import 'package:quick_notes/core/motion/quick_notes_visual_preset.dart';
import 'package:quick_notes/views/widgets/quick_notes_visual_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickNotesVisualPreset.baseline Forensic & Locked Configuration Tests', () {
    // -------------------------------------------------------------------------
    // 1. Existence & Identity
    // -------------------------------------------------------------------------
    test('1. Baseline preset exists and has correct identifier', () {
      expect(QuickNotesVisualPreset.baseline, isNotNull);
      expect(QuickNotesVisualPreset.baseline.name, 'Baseline');
    });

    // -------------------------------------------------------------------------
    // 2. Immutability
    // -------------------------------------------------------------------------
    test('2. Baseline is a compile-time const and immutable', () {
      const presetA = QuickNotesVisualPreset.baseline;
      const presetB = QuickNotesVisualPreset.baseline;
      expect(identical(presetA, presetB), isTrue);
    });

    // -------------------------------------------------------------------------
    // 3 & 4. Exact Locked Configuration Properties
    // -------------------------------------------------------------------------
    test('3 & 4. Explicitly asserts every property of the physically validated Locked Configuration', () {
      const preset = QuickNotesVisualPreset.baseline;

      // GEOMETRY SPRING (Phase 8C-A / 8D-R2)
      expect(preset.stiffness, 195.0, reason: 'Stiffness must exactly equal 195.0');
      expect(preset.damping, 19.5, reason: 'Viscous damping must exactly equal 19.5');

      // STRETCH & ASYMMETRIC LEAD-FOLLOW DYNAMICS (Fidelity Lab lines 610-612)
      expect(preset.stretch, 0.75, reason: 'Stretch factor must exactly equal 0.75');
      expect(preset.leadBounce, 0.10, reason: 'Lead bounce reduction must exactly equal 0.10');
      expect(preset.followDelaySeconds, 0.04, reason: 'Follow delay must exactly equal 0.04s (40ms)');

      // CONTENT OPTICS & SPATIAL FOLLOW (Fidelity Lab lines 613-615)
      expect(preset.contentBlur, 8.0, reason: 'Content blur sigma must exactly equal 8.0');
      expect(preset.contentFollow, 1.0, reason: 'Content follow must exactly equal 1.0 (ride moving surface)');
      expect(preset.contentSlide, 0.0, reason: 'Content directional slide must exactly equal 0.0');

      // CONTENT HANDOFF TIMING & SCALE (Fidelity Lab lines 775-779 / MorphContentController lines 11-15)
      expect(preset.contentOutEnd, 0.40, reason: 'Outgoing content must fade to 0 by 40% progress');
      expect(preset.contentInStart, 0.30, reason: 'Incoming content must begin fading at 30% progress');
      expect(preset.contentInEnd, 0.80, reason: 'Incoming content must reach full opacity by 80% progress');
      expect(preset.oldScaleTo, 0.92, reason: 'Outgoing content scales down to 0.92');
      expect(preset.newScaleFrom, 0.90, reason: 'Incoming content scales up from 0.90');

      // VERIFY CORE CONFIG CONVERSIONS
      final QuickNotesMorphGeometryConfig geom = preset.toGeometryConfig(anchor: Alignment.topRight);
      expect(geom.stiffness, 195.0);
      expect(geom.damping, 19.5);
      expect(geom.stretch, 0.75);
      expect(geom.leadBounce, 0.10);
      expect(geom.followDelaySeconds, 0.04);
      expect(geom.seedScale, 1.0);
      expect(geom.anchor, Alignment.topRight);

      // Verify derived dynamics
      final double expectedBaseZeta = 19.5 / (2.0 * math.sqrt(195.0));
      expect(geom.baseZeta, closeTo(expectedBaseZeta, 1e-4));
      expect(geom.leadMultiplier, closeTo(1.0 + 2.2 * 0.75, 1e-4)); // 2.65
      expect(geom.leadZeta, closeTo(expectedBaseZeta - 0.10, 1e-4));

      final QuickNotesMorphContentConfig content = preset.toContentConfig(anchor: Alignment.center);
      expect(content.contentBlur, 8.0);
      expect(content.contentFollow, 1.0);
      expect(content.contentSlide, 0.0);
      expect(content.contentOutEnd, 0.40);
      expect(content.contentInStart, 0.30);
      expect(content.contentInEnd, 0.80);
      expect(content.oldScaleTo, 0.92);
      expect(content.newScaleFrom, 0.90);
      expect(content.anchor, Alignment.center);
    });

    // -------------------------------------------------------------------------
    // 5. Renderer Independence
    // -------------------------------------------------------------------------
    test('5. Preset is strictly renderer-independent (no glass or shader properties)', () {
      // Intentionally verify preset has no glass fields by ensuring properties match only motion
      const dynamic dynPreset = QuickNotesVisualPreset.baseline;

      // Dart dynamic NoSuchMethodError checks verifying no glass settings leaked into the preset
      expect(() => dynPreset.sigma, throwsNoSuchMethodError);
      expect(() => dynPreset.blurSigma, throwsNoSuchMethodError);
      expect(() => dynPreset.tintColor, throwsNoSuchMethodError);
      expect(() => dynPreset.useFrost, throwsNoSuchMethodError);
      expect(() => dynPreset.specularAngle, throwsNoSuchMethodError);
      expect(() => dynPreset.innerShadow, throwsNoSuchMethodError);
    });

    // -------------------------------------------------------------------------
    // 6. Overrides Do Not Mutate Canonical Baseline
    // -------------------------------------------------------------------------
    test('6. copyWith and overrides create new instances without mutating Baseline', () {
      final modifiedMotion = QuickNotesVisualPreset.baseline.withMotion(
        stiffness: 250.0,
        damping: 25.0,
      );
      expect(modifiedMotion.stiffness, 250.0);
      expect(modifiedMotion.damping, 25.0);
      expect(QuickNotesVisualPreset.baseline.stiffness, 195.0);
      expect(QuickNotesVisualPreset.baseline.damping, 19.5);

      final modifiedStretch = QuickNotesVisualPreset.baseline.withStretch(
        stretch: 0.30,
        leadBounce: 0.0,
        followDelaySeconds: 0.0,
      );
      expect(modifiedStretch.stretch, 0.30);
      expect(modifiedStretch.leadBounce, 0.0);
      expect(modifiedStretch.followDelaySeconds, 0.0);
      expect(QuickNotesVisualPreset.baseline.stretch, 0.75);
      expect(QuickNotesVisualPreset.baseline.leadBounce, 0.10);
      expect(QuickNotesVisualPreset.baseline.followDelaySeconds, 0.04);

      final modifiedContent = QuickNotesVisualPreset.baseline.withContent(
        contentBlur: 4.0,
        oldScaleTo: 0.85,
        newScaleFrom: 0.80,
      );
      expect(modifiedContent.contentBlur, 4.0);
      expect(modifiedContent.oldScaleTo, 0.85);
      expect(modifiedContent.newScaleFrom, 0.80);
      expect(QuickNotesVisualPreset.baseline.contentBlur, 8.0);
      expect(QuickNotesVisualPreset.baseline.oldScaleTo, 0.92);
      expect(QuickNotesVisualPreset.baseline.newScaleFrom, 0.90);
    });

    // -------------------------------------------------------------------------
    // 7. Consumption by QuickNotesVisualTransition
    // -------------------------------------------------------------------------
    testWidgets('7. Baseline is successfully consumed by QuickNotesVisualTransition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickNotesVisualTransition(
              state: false,
              preset: QuickNotesVisualPreset.baseline,
              collapsedSize: Size(44, 44),
              expandedSize: Size(192, 100),
              collapsedChild: SizedBox(
                key: ValueKey('test_collapsed'),
                width: 44,
                height: 44,
              ),
              expandedChild: SizedBox(
                key: ValueKey('test_expanded'),
                width: 192,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('test_collapsed')), findsOneWidget);
    });
  });
}
