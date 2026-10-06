import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_physical_device_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

void main() {
  Widget buildHarness() {
    return const MaterialApp(
      home: LiquidGlassMorphPhysicalDeviceLabScreen(),
    );
  }

  group('Phase 8C-P — Physical Device Morphing Lab Verification', () {
    testWidgets(
      '1–5 & 13: Lab screen builds, preview renders with isolated BottomBarGlassSurface, and States A (128×48), B (268×176), and C (216×96) exist and transition cleanly',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // 1. Lab screen builds
        expect(
          find.byKey(const ValueKey<String>('phys_lab_appbar_title')),
          findsOneWidget,
        );
        expect(find.text('Morphing — Physical Device Lab'), findsOneWidget);

        // 2. Preview renders with Quick Notes BottomBarGlassSurface
        expect(
          find.byKey(const ValueKey<String>('phys_lab_preview_stage')),
          findsOneWidget,
        );
        final Finder glassFinder = find.byKey(
          const ValueKey<String>('phys_lab_glass_surface'),
        );
        expect(glassFinder, findsOneWidget);
        final BottomBarGlassSurface initialSurface =
            tester.widget<BottomBarGlassSurface>(glassFinder);
        expect(initialSurface.useFrost, isTrue);
        expect(initialSurface.width, closeTo(128.0, 0.1));
        expect(initialSurface.height, closeTo(48.0, 0.1));

        // 13. Lab remains isolated (BottomBarGlassSurface sigma 3.0, 4 outer + 4 inset shadows, zero LiquidGlassBlender)
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

        final Finder decoratedBoxes = find.descendant(
          of: glassFinder,
          matching: find.byType(DecoratedBox),
        );
        final DecoratedBox outerBox =
            tester.widget<DecoratedBox>(decoratedBoxes.first);
        expect(
          (outerBox.decoration as BoxDecoration).boxShadow?.length,
          equals(4),
        );
        final DecoratedBox innerBox =
            tester.widget<DecoratedBox>(decoratedBoxes.at(1));
        final inset.BoxDecoration innerDeco =
            innerBox.decoration as inset.BoxDecoration;
        expect(innerDeco.boxShadow?.length, equals(4));
        for (final BoxShadow rawShadow in innerDeco.boxShadow!) {
          expect((rawShadow as inset.BoxShadow).inset, isTrue);
        }

        for (final Widget w in tester.allWidgets) {
          final String typeName = w.runtimeType.toString();
          expect(typeName.contains('LiquidGlassBlender'), isFalse);
          expect(typeName == 'LiquidGlassMorph', isFalse);
        }

        // 3. State A exists initially
        expect(
          find.byKey(const ValueKey<String>('phys_lab_stateA_text')),
          findsOneWidget,
        );

        // 4. Transition to State B (268×176) and verify State B exists
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_btn_a_to_b')),
        );
        await tester.pump();
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          find.byKey(const ValueKey<String>('phys_lab_stateB_text')),
          findsOneWidget,
        );
        final BottomBarGlassSurface surfaceB =
            tester.widget<BottomBarGlassSurface>(glassFinder);
        expect(surfaceB.width, closeTo(268.0, 0.5));
        expect(surfaceB.height, closeTo(176.0, 0.5));

        // 5. Transition to State C (216×96) and verify State C exists
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_btn_manual_retarget_c')),
        );
        await tester.pump();
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          find.byKey(const ValueKey<String>('phys_lab_stateC_text')),
          findsOneWidget,
        );
        final BottomBarGlassSurface surfaceC =
            tester.widget<BottomBarGlassSurface>(glassFinder);
        expect(surfaceC.width, closeTo(216.0, 0.5));
        expect(surfaceC.height, closeTo(96.0, 0.5));
      },
    );

    testWidgets(
      '6–9 & 12: Primary/Manual controls, Anchor selector, Geometry controls, Content controls, Diagnostics & Reset work accurately',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // 6. Primary & Manual controls exist
        for (final String keyName in const <String>[
          'phys_btn_a_to_b',
          'phys_btn_b_to_a',
          'phys_btn_a_to_b_to_a',
          'phys_btn_a_to_b_to_c',
          'phys_btn_rapid_sequence',
          'phys_btn_reset',
          'phys_btn_start_a_to_b',
          'phys_btn_manual_reverse',
          'phys_btn_manual_retarget_c',
          'phys_btn_rapid_test',
        ]) {
          expect(find.byKey(ValueKey<String>(keyName)), findsOneWidget);
        }

        // Size / Position Test Modes exist
        for (final String keyName in const <String>[
          'phys_mode_sizeOnly',
          'phys_mode_positionOnly',
          'phys_mode_sizeAndPosition',
        ]) {
          expect(find.byKey(ValueKey<String>(keyName)), findsOneWidget);
        }

        // 7. Anchor selector exists (Center, Top Left, Top Right, Bottom Left, Bottom Right)
        for (final String keyName in const <String>[
          'phys_anchor_center',
          'phys_anchor_topLeft',
          'phys_anchor_topRight',
          'phys_anchor_bottomLeft',
          'phys_anchor_bottomRight',
        ]) {
          expect(find.byKey(ValueKey<String>(keyName)), findsOneWidget);
        }

        // 8. Geometry controls exist
        for (final String keyName in const <String>[
          'phys_stretch_0.0',
          'phys_stretch_0.25',
          'phys_stretch_0.5',
          'phys_stretch_0.75',
          'phys_stretch_1.0',
          'phys_leadBounce_0.0',
          'phys_leadBounce_0.10',
          'phys_leadBounce_0.25',
          'phys_followDelay_0 ms',
          'phys_followDelay_40 ms',
          'phys_followDelay_100 ms',
          'phys_followDelay_150 ms',
        ]) {
          expect(find.byKey(ValueKey<String>(keyName)), findsOneWidget);
        }

        // 9. Content controls exist
        for (final String keyName in const <String>[
          'phys_contentBlur_0',
          'phys_contentBlur_4',
          'phys_contentBlur_8',
          'phys_contentBlur_12',
          'phys_contentFollow_0.00',
          'phys_contentFollow_0.25',
          'phys_contentFollow_0.50',
          'phys_contentFollow_0.75',
          'phys_contentFollow_1.00',
          'phys_contentSlide_-24',
          'phys_contentSlide_-12',
          'phys_contentSlide_0',
          'phys_contentSlide_+12',
          'phys_contentSlide_+24',
        ]) {
          expect(find.byKey(ValueKey<String>(keyName)), findsOneWidget);
        }

        // Mutate anchor, blur, follow, slide, stretch, bounce, delay, and state
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_anchor_topRight')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_contentBlur_12')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_contentFollow_1.00')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_contentSlide_+24')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_stretch_1.0')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_leadBounce_0.25')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_followDelay_150 ms')),
        );
        await tester.pump();

        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('diag_current_anchor')),
              )
              .data,
          equals('Current Anchor: Top-Right'),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('diag_content_blur')),
              )
              .data,
          equals('Current contentBlur: 12'),
        );

        // Start A -> B and manually interrupt with Reverse mid-flight
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_btn_start_a_to_b')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('phys_status_animation')),
              )
              .data,
          equals('Animation: RUNNING'),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('phys_btn_manual_reverse')),
        );
        await tester.pump();
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('phys_status_animation')),
              )
              .data,
          equals('Animation: IDLE'),
        );

        // 12. Reset works and restores defaults
        await tester.tap(find.byKey(const ValueKey<String>('phys_btn_reset')));
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('diag_current_anchor')),
              )
              .data,
          equals('Current Anchor: Center'),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('diag_content_blur')),
              )
              .data,
          equals('Current contentBlur: 8'),
        );
        expect(
          find.byKey(const ValueKey<String>('phys_lab_stateA_text')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '10 & 11: Checklist exists with all items initialized to NOT TESTED, supports PASS/FAIL/NOT TESTED, and reveals Notes field on FAIL',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 4200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('phys_lab_checklist_card')),
          findsOneWidget,
        );

        // Verify ALL 39 checklist items initialize to NOT TESTED (never auto-marked PASS)
        final int totalItems = kPhysicalDeviceChecklistSpecs.length;
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const ValueKey<String>('phys_lab_checklist_summary'),
                ),
              )
              .data,
          equals('PASS: 0 • FAIL: 0 • NOT TESTED: $totalItems'),
        );

        // Verify PASS / FAIL / NOT TESTED controls exist for 'basic_a_to_b'
        final Finder passChip = find.byKey(
          const ValueKey<String>('checklist_basic_a_to_b_pass'),
        );
        final Finder failChip = find.byKey(
          const ValueKey<String>('checklist_basic_a_to_b_fail'),
        );
        final Finder notTestedChip = find.byKey(
          const ValueKey<String>('checklist_basic_a_to_b_notTested'),
        );
        expect(passChip, findsOneWidget);
        expect(failChip, findsOneWidget);
        expect(notTestedChip, findsOneWidget);

        // Notes field is hidden before FAIL is selected
        expect(
          find.byKey(const ValueKey<String>('checklist_notes_basic_a_to_b')),
          findsNothing,
        );

        // Mark as PASS
        await tester.tap(passChip);
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const ValueKey<String>('phys_lab_checklist_summary'),
                ),
              )
              .data,
          equals('PASS: 1 • FAIL: 0 • NOT TESTED: ${totalItems - 1}'),
        );

        // Mark as FAIL -> Notes TextField appears
        await tester.tap(failChip);
        await tester.pump();
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const ValueKey<String>('phys_lab_checklist_summary'),
                ),
              )
              .data,
          equals('PASS: 0 • FAIL: 1 • NOT TESTED: ${totalItems - 1}'),
        );
        final Finder notesField = find.byKey(
          const ValueKey<String>('checklist_notes_basic_a_to_b'),
        );
        expect(notesField, findsOneWidget);
        await tester.enterText(notesField, 'Observed on physical device');
        await tester.pump();
        expect(find.text('Observed on physical device'), findsOneWidget);
      },
    );
  });
}
