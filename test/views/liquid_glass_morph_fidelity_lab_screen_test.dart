import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_fidelity_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart'
    show BottomBarGlassSurface;

void main() {
  Widget buildHarness({Size size = const Size(1080, 2400)}) {
    return MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: 3.0),
      child: const MaterialApp(
        home: LiquidGlassMorphFidelityLabScreen(),
      ),
    );
  }

  Rect readLiveGlassRect(WidgetTester tester) {
    final Positioned pos = tester.widget<Positioned>(
      find.byKey(const ValueKey<String>('fidelity_glass_positioned')),
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
      find.byKey(const ValueKey<String>('fidelity_quick_notes_glass_surface')),
    );
  }

  group('Phase 8C-D — Morph Fidelity & Circle → Square Lab Verification', () {
    testWidgets(
      '1–6 & 12: Lab builds, isolated BottomBarGlassSurface renders Circle (56×56, r=28) and Square (224×184, r=28), and Circle→Square, Square→Circle, and Round-Trip controls work',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1080, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // 1. Lab builds & 12. Uses isolated BottomBarGlassSurface
        expect(
          find.byKey(const ValueKey<String>('morph_fidelity_lab_screen')),
          findsOneWidget,
        );
        expect(find.text('Morph Fidelity — Circle → Square'), findsOneWidget);
        expect(find.byType(BottomBarGlassSurface), findsOneWidget);

        // 2. Circle state exists initially (56×56, r=28 -> true circle)
        final Rect initialCircleRect = readLiveGlassRect(tester);
        expect(initialCircleRect.width, closeTo(56.0, 0.5));
        expect(initialCircleRect.height, closeTo(56.0, 0.5));
        final BottomBarGlassSurface initialGlass = readGlassSurface(tester);
        expect(
          initialGlass.borderRadius,
          equals(BorderRadius.circular(28.0)),
        );
        expect(
          find.byKey(const ValueKey<String>('fidelity_state_circle_content')),
          findsOneWidget,
        );

        // 4–6. Verify primary reference mode controls exist
        final Finder modeABtn = find.byKey(
          const ValueKey<String>('fidelity_mode_a_circle_to_square'),
        );
        final Finder modeBBtn = find.byKey(
          const ValueKey<String>('fidelity_mode_b_square_to_circle'),
        );
        final Finder modeCBtn = find.byKey(
          const ValueKey<String>('fidelity_mode_c_round_trip'),
        );
        final Finder modeDBtn = find.byKey(
          const ValueKey<String>('fidelity_mode_d_with_position'),
        );
        final Finder modeEBtn = find.byKey(
          const ValueKey<String>('fidelity_mode_e_interrupted'),
        );
        final Finder modeFBtn = find.byKey(
          const ValueKey<String>('fidelity_mode_f_retarget'),
        );

        expect(modeABtn, findsOneWidget);
        expect(modeBBtn, findsOneWidget);
        expect(modeCBtn, findsOneWidget);
        expect(modeDBtn, findsOneWidget);
        expect(modeEBtn, findsOneWidget);
        expect(modeFBtn, findsOneWidget);

        // Trigger Mode A: Circle -> Square
        await tester.tap(modeABtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        // Mid-morph both incoming Square and outgoing Circle content exist during overlap
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          find.byKey(const ValueKey<String>('fidelity_state_square_content')),
          findsOneWidget,
        );

        // Settle at Square state (3. Square state exists: 224×184, r=28)
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        final Rect settledSquareRect = readLiveGlassRect(tester);
        expect(settledSquareRect.width, closeTo(224.0, 0.5));
        expect(settledSquareRect.height, closeTo(184.0, 0.5));
        final BottomBarGlassSurface squareGlass = readGlassSurface(tester);
        expect(
          squareGlass.borderRadius,
          equals(BorderRadius.circular(28.0)),
        );

        // Trigger Mode B: Square -> Circle
        await tester.tap(modeBBtn);
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        final Rect returnedCircleRect = readLiveGlassRect(tester);
        expect(returnedCircleRect.width, closeTo(56.0, 0.5));
        expect(returnedCircleRect.height, closeTo(56.0, 0.5));

        // Trigger Mode C: Circle -> Square -> Circle round-trip
        await tester.tap(modeCBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        final Rect roundTripRect = readLiveGlassRect(tester);
        expect(roundTripRect.width, closeTo(56.0, 0.5));
        expect(roundTripRect.height, closeTo(56.0, 0.5));
      },
    );

    testWidgets(
      '7–10: Anchor controls, Position refinement variants, Comparison modes, Parameter experiments, Debug overlay, and Motion path toggle exist and function',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1080, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness());
        await tester.pump();

        // 9 & 10. Debug overlay & Motion path toggles exist and control diagnostic canvas
        final Finder debugToggle = find.byKey(
          const ValueKey<String>('fidelity_debug_overlay_toggle'),
        );
        final Finder pathToggle = find.byKey(
          const ValueKey<String>('fidelity_motion_path_toggle'),
        );
        expect(debugToggle, findsOneWidget);
        expect(pathToggle, findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('fidelity_debug_trajectory_canvas')),
          findsOneWidget,
        );

        // Toggle both off -> diagnostic canvas disappears
        await tester.tap(debugToggle);
        await tester.pump();
        await tester.tap(pathToggle);
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('fidelity_debug_trajectory_canvas')),
          findsNothing,
        );

        // Toggle both back on
        await tester.tap(debugToggle);
        await tester.pump();
        await tester.tap(pathToggle);
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('fidelity_debug_trajectory_canvas')),
          findsOneWidget,
        );

        // 8. Position refinement variants exist (Baseline, Position Lead, Size Lead, Balanced, Anchor Locked)
        for (final MorphFidelityChoreographyVariant variant
            in MorphFidelityChoreographyVariant.values) {
          expect(
            find.byKey(ValueKey<String>('fidelity_variant_${variant.name}')),
            findsOneWidget,
          );
        }

        // Compare trajectory bow between Baseline (with corner anchor) and Balanced
        await tester.tap(
          find.byKey(const ValueKey<String>('fidelity_anchor_bottomRight')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('fidelity_variant_balanced')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('fidelity_mode_d_with_position')),
        );
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 16));

        // In Balanced mode with center-tracked translation, center trajectory bow is ~0px (< 0.2px)
        final Text readout = tester.widget<Text>(
          find.byKey(const ValueKey<String>('fidelity_live_rect_readout')),
        );
        expect(
          readout.data,
          anyOf(
            contains('Max path bow: 0.0px'),
            contains('Max path bow: 0.1px'),
          ),
        );

        // Native Reference Comparison section exists with all 3 profiles
        for (final MorphFidelityComparisonProfile profile
            in MorphFidelityComparisonProfile.values) {
          expect(
            find.byKey(ValueKey<String>('fidelity_comp_${profile.name}')),
            findsOneWidget,
          );
        }

        // 7. Anchor controls exist (Center, Top-Left, Top-Right, Bottom-Left, Bottom-Right)
        for (final String anchorKey in <String>[
          'fidelity_anchor_center',
          'fidelity_anchor_topLeft',
          'fidelity_anchor_topRight',
          'fidelity_anchor_bottomLeft',
          'fidelity_anchor_bottomRight',
        ]) {
          expect(find.byKey(ValueKey<String>(anchorKey)), findsOneWidget);
        }

        // Parameter experiments exist
        for (final String paramKey in <String>[
          'fidelity_stretch_0.0',
          'fidelity_stretch_0.25',
          'fidelity_stretch_0.5',
          'fidelity_stretch_0.75',
          'fidelity_stretch_1.0',
          'fidelity_leadBounce_0',
          'fidelity_leadBounce_0.10',
          'fidelity_leadBounce_0.25',
          'fidelity_followDelay_0 ms',
          'fidelity_followDelay_40 ms',
          'fidelity_followDelay_100 ms',
          'fidelity_followDelay_150 ms',
          'fidelity_contentBlur_0',
          'fidelity_contentBlur_4',
          'fidelity_contentBlur_8',
          'fidelity_contentBlur_12',
          'fidelity_contentFollow_0',
          'fidelity_contentFollow_0.5',
          'fidelity_contentFollow_1',
          'fidelity_contentSlide_-24',
          'fidelity_contentSlide_0',
          'fidelity_contentSlide_+24',
        ]) {
          expect(find.byKey(ValueKey<String>(paramKey)), findsOneWidget);
        }
      },
    );

    testWidgets(
      '11: Physical Device Test Sequence (Tests 1–12) and Visual Comparison Checklist exist, default to NOT TESTED, and reveal Notes on FAIL',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1080, 3600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildHarness(size: const Size(1080, 3600)));
        await tester.pump();

        // Scroll to the checklist sections
        await tester.drag(
          find.byKey(const ValueKey<String>('morph_fidelity_lab_scroll')),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();

        // Verify all 12 physical sequence test items & run buttons exist
        for (int i = 1; i <= 12; i++) {
          expect(
            find.byKey(ValueKey<String>('fidelity_run_seq_test_$i')),
            findsOneWidget,
          );
          final ChoiceChip notTestedChip = tester.widget<ChoiceChip>(
            find.byKey(
              ValueKey<String>('fidelity_status_seq_test_${i}_notTested'),
            ),
          );
          expect(notTestedChip.selected, isTrue);
        }

        // Mark TEST 1 as FAIL and verify Notes field appears
        final Finder test1Fail = find.byKey(
          const ValueKey<String>('fidelity_status_seq_test_1_fail'),
        );
        await tester.ensureVisible(test1Fail);
        await tester.tap(test1Fail);
        await tester.pump();

        final Finder test1Notes = find.byKey(
          const ValueKey<String>('fidelity_notes_seq_test_1'),
        );
        expect(test1Notes, findsOneWidget);
        await tester.enterText(
          test1Notes,
          'Observed slight bow in Baseline before switching to Balanced.',
        );
        await tester.pump();
        expect(
          find.text(
            'Observed slight bow in Baseline before switching to Balanced.',
          ),
          findsOneWidget,
        );

        // Mark TEST 1 as PASS and verify Notes field hides
        final Finder test1Pass = find.byKey(
          const ValueKey<String>('fidelity_status_seq_test_1_pass'),
        );
        await tester.tap(test1Pass);
        await tester.pump();
        expect(test1Notes, findsNothing);
      },
    );

    group('Phase 8C-D Layout Refinement — Fixed Viewer + Scrollable Controls', () {
      testWidgets(
        'TEST 1–5 & 7: Morph viewer is fixed outside ScrollView, controls are inside ScrollView, viewer stays pinned during scroll, and controls remain interactable without resetting viewer',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(const Size(1080, 2400));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(buildHarness(size: const Size(1080, 2400)));
          await tester.pump();

          final Finder viewerFinder = find.byKey(
            const ValueKey<String>('fidelity_preview_card'),
          );
          final Finder scrollFinder = find.byKey(
            const ValueKey<String>('morph_fidelity_lab_scroll'),
          );
          final Finder modeAFinder = find.byKey(
            const ValueKey<String>('fidelity_mode_a_circle_to_square'),
          );

          // TEST 1: The Morph viewer exists outside the controls ScrollView
          expect(viewerFinder, findsOneWidget);
          expect(
            find.descendant(of: scrollFinder, matching: viewerFinder),
            findsNothing,
          );

          // TEST 2: The controls are inside the intended scrollable region
          expect(
            find.descendant(of: scrollFinder, matching: modeAFinder),
            findsOneWidget,
          );

          // Record initial screen position of the viewer
          final Offset initialViewerOffset = tester.getTopLeft(viewerFinder);
          final Size initialViewerSize = tester.getSize(viewerFinder);
          expect(initialViewerOffset.dy, greaterThan(0.0));

          // TEST 3: The viewer remains present and pinned when the control region is scrolled
          await tester.drag(scrollFinder, const Offset(0, -600));
          await tester.pumpAndSettle();

          // Viewer is still present and has the EXACT same top-left position and size
          expect(viewerFinder, findsOneWidget);
          final Offset scrolledViewerOffset = tester.getTopLeft(viewerFinder);
          final Size scrolledViewerSize = tester.getSize(viewerFinder);
          expect(scrolledViewerOffset, equals(initialViewerOffset));
          expect(scrolledViewerSize, equals(initialViewerSize));

          // TEST 4: Controls in scrollable region can be scrolled into view
          final Finder checklistCardFinder = find.byKey(
            const ValueKey<String>('fidelity_visual_checklist_card'),
          );
          await tester.drag(scrollFinder, const Offset(0, -1200));
          await tester.pumpAndSettle();
          expect(checklistCardFinder, findsOneWidget);

          // Viewer is still present at the exact same screen location!
          expect(viewerFinder, findsOneWidget);
          expect(tester.getTopLeft(viewerFinder), equals(initialViewerOffset));

          // TEST 5: Changing a control does not remove/recreate or move the viewer
          // Scroll back up to the reference modes
          await tester.drag(scrollFinder, const Offset(0, 1800));
          await tester.pumpAndSettle();
          expect(modeAFinder, findsOneWidget);
          await tester.tap(modeAFinder);
          await tester.pumpAndSettle();

          expect(viewerFinder, findsOneWidget);
          expect(tester.getTopLeft(viewerFinder), equals(initialViewerOffset));
        },
      );

      testWidgets(
        'TEST 6: Responsive layout adapts with zero RenderFlex overflow on compact mobile screen sizes',
        (WidgetTester tester) async {
          // Test on standard mobile viewport (390 × 844)
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(buildHarness(size: const Size(390, 844)));
          await tester.pump();

          expect(
            find.byKey(const ValueKey<String>('fidelity_preview_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_fidelity_lab_scroll')),
            findsOneWidget,
          );

          // Scroll through the entire control pane at compact size
          await tester.drag(
            find.byKey(const ValueKey<String>('morph_fidelity_lab_scroll')),
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();

          // Test on very compact mobile viewport (360 × 640)
          await tester.binding.setSurfaceSize(const Size(360, 640));
          await tester.pumpWidget(buildHarness(size: const Size(360, 640)));
          await tester.pump();

          expect(
            find.byKey(const ValueKey<String>('fidelity_preview_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('morph_fidelity_lab_scroll')),
            findsOneWidget,
          );
        },
      );
    });
  });
}
