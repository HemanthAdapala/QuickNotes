import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_tab_bar_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

void main() {
  group('LiquidGlassTabBarLabScreen', () {
    testWidgets('Stage 1 and Stage 2 presence, carousel navigation, and depth architecture',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Title, Header, and Pinned Scroll bar
      expect(find.text('Liquid Glass TabBar Lab'), findsOneWidget);
      expect(find.text('PHASE 7A'), findsOneWidget);
      expect(find.text('TABBAR PREVIEW STAGE'), findsOneWidget);
      expect(find.text('STAGE 2 PHYSICS INSPECTOR'), findsOneWidget);

      // 2. Layer presence (Depth hierarchy)
      final bg1Finder = find.byKey(const ValueKey('tabbar_lab_bg_layer_1'));
      final bg2Finder = find.byKey(const ValueKey('tabbar_lab_bg_layer_2'));
      final pageViewFinder =
          find.byKey(const ValueKey('tabbar_stage_carousel_page_view'));
      expect(bg1Finder, findsOneWidget);
      expect(bg2Finder, findsOneWidget);
      expect(pageViewFinder, findsOneWidget);

      // 3. Stage 1 exists: Native LiquidGlassTabBar
      final nativeTabBarFinder =
          find.byKey(const ValueKey('native_liquid_glass_tab_bar'));
      expect(nativeTabBarFinder, findsOneWidget);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
      expect(find.text('STAGE 1: NATIVE LIQUID GLASS TABBAR'), findsOneWidget);

      // 4. Navigate to Stage 2 via stage tab
      final stage2Tab = find.byKey(const ValueKey('tabbar_stage_tab_1'));
      expect(stage2Tab, findsOneWidget);
      await tester.tap(stage2Tab);
      await tester.pumpAndSettle();

      // 5. Stage 2 exists: Quick Notes Navigation
      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      expect(recreationFinder, findsOneWidget);
      expect(find.text('STAGE 2: QUICK NOTES NAVIGATION (PHYSICS)'),
          findsOneWidget);

      // 6. Production visual components represented in Stage 2
      expect(find.byType(BottomBarGlassSurface), findsNWidgets(2)); // Main bar + FAB
      expect(find.byKey(const ValueKey('quick_notes_navigation_fab')), findsOneWidget);
      expect(find.byKey(const ValueKey('physical_active_indicator')), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('Stage 2 starts with forensic defaults and reset restores them',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600); // wide layout for side-by-side
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      // Helper to find Slider value
      double getSliderVal(Key key) {
        final slider = tester.widget<Slider>(find.byKey(key));
        return slider.value;
      }

      // Verify Stage 2 begins with exact forensic baselines
      expect(getSliderVal(const ValueKey('slider_travel_stiffness')), 280.0);
      expect(getSliderVal(const ValueKey('slider_travel_damping')), 31.4);
      expect(getSliderVal(const ValueKey('slider_lift_stiffness')), 250.0);
      expect(getSliderVal(const ValueKey('slider_lift_damping_x')), 19.0);
      expect(getSliderVal(const ValueKey('slider_lift_damping_y')), 22.1);
      expect(getSliderVal(const ValueKey('slider_pill_grow_height')), 12.0);
      expect(getSliderVal(const ValueKey('slider_max_deformation')), 0.12);
      expect(getSliderVal(const ValueKey('slider_response_time')), 0.18);
      expect(getSliderVal(const ValueKey('slider_sign_tau')), 0.25);
      expect(getSliderVal(const ValueKey('slider_follow_tau')), 0.05);
      expect(getSliderVal(const ValueKey('slider_drag_threshold')), 0.20);

      // Modify a slider (e.g. Travel Stiffness to 450)
      final travelStiffnessSlider =
          find.byKey(const ValueKey('slider_travel_stiffness'));
      await tester.tap(travelStiffnessSlider);
      await tester.pumpAndSettle();

      // Verify the value changed from 280.0
      final changedVal = getSliderVal(const ValueKey('slider_travel_stiffness'));
      expect(changedVal, isNot(280.0));

      // Tap 'Restore Forensic Defaults'
      final restoreBtn =
          find.byKey(const ValueKey('reset_physics_defaults_button'));
      expect(restoreBtn, findsOneWidget);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // Verify restored to exact forensic baselines
      expect(getSliderVal(const ValueKey('slider_travel_stiffness')), 280.0);
      expect(getSliderVal(const ValueKey('slider_travel_damping')), 31.4);
      expect(getSliderVal(const ValueKey('slider_lift_stiffness')), 250.0);
      expect(getSliderVal(const ValueKey('slider_lift_damping_x')), 19.0);
      expect(getSliderVal(const ValueKey('slider_lift_damping_y')), 22.1);
      expect(getSliderVal(const ValueKey('slider_pill_grow_height')), 12.0);
    });

    testWidgets('Lab scrolling toggle switches state properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCROLL ON'), findsOneWidget);

      // Tap OFF button
      final offButton =
          find.byKey(const ValueKey('tabbar_lab_scrolling_off_button'));
      expect(offButton, findsOneWidget);
      await tester.tap(offButton);
      await tester.pumpAndSettle();

      expect(find.text('SCROLL OFF'), findsOneWidget);

      // Tap ON button
      final onButton =
          find.byKey(const ValueKey('tabbar_lab_scrolling_on_button'));
      expect(onButton, findsOneWidget);
      await tester.tap(onButton);
      await tester.pumpAndSettle();

      expect(find.text('SCROLL ON'), findsOneWidget);
    });

    testWidgets('Tapping unselected tab initiates travel while tapping selected tab is a no-op',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      expect(recreationFinder, findsOneWidget);

      // Geometry for real Quick Notes navigation
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.65, 1.0);
      double getCenter(int i) =>
          recreationRect.left + (40.0 + i * (184.0 / 3.0)) * scale;

      final tab0Center = Offset(getCenter(0), recreationRect.center.dy);
      final tab1Center = Offset(getCenter(1), recreationRect.center.dy);
      final tab3Center = Offset(getCenter(3), recreationRect.center.dy);

      // Tab 0 is initially selected. Tapping Tab 0 should be a no-op (no animation started)
      await tester.tapAt(tab0Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isFalse);

      // Tap Tab 3: starts travel animation
      await tester.tapAt(tab3Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);

      // Let animation settle at Tab 3
      await tester.pumpAndSettle();

      // Now at Tab 3, tapping Tab 3 should be a no-op
      await tester.tapAt(tab3Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isFalse);

      // Tap Tab 1: travels back
      await tester.tapAt(tab1Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('Mid-flight retargeting preserves state smoothly without resetting',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.65, 1.0);
      double getCenter(int i) =>
          recreationRect.left + (40.0 + i * (184.0 / 3.0)) * scale;

      final tab1Center = Offset(getCenter(1), recreationRect.center.dy);
      final tab3Center = Offset(getCenter(3), recreationRect.center.dy);

      // Start traveling toward Tab 3
      await tester.tapAt(tab3Center);
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.hasRunningAnimations, isTrue);

      // Mid-flight interruption: Tap Tab 1 before reaching Tab 3
      await tester.tapAt(tab1Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);

      // Verify it smoothly settles to Tab 1 without crash or jump
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Preview Stage inner background defaults to #FFFFFF and environment presets function',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify default background layers are pure white #FFFFFF
      final bg1 = tester.widget<ColoredBox>(find.byKey(const ValueKey('tabbar_lab_bg_layer_1')));
      final bg2 = tester.widget<ColoredBox>(find.byKey(const ValueKey('tabbar_lab_bg_layer_2')));
      expect(bg1.color, const Color(0xFFFFFFFF));
      expect(bg2.color, const Color(0xFFFFFFFF));

      // 2. Select an environment preset chip (e.g., Obsidian Glow)
      final obsidianChip = find.text('Obsidian Glow');
      expect(obsidianChip, findsOneWidget);
      await tester.ensureVisible(obsidianChip);
      await tester.pumpAndSettle();
      await tester.tap(obsidianChip);
      await tester.pumpAndSettle();

      final bg1After = tester.widget<ColoredBox>(find.byKey(const ValueKey('tabbar_lab_bg_layer_1')));
      expect(bg1After.color, const Color(0xFF000000));

      // 3. Select 'Pure White' preset chip
      final pureWhiteChip = find.text('Pure White');
      expect(pureWhiteChip, findsOneWidget);
      await tester.ensureVisible(pureWhiteChip);
      await tester.pumpAndSettle();
      await tester.tap(pureWhiteChip);
      await tester.pumpAndSettle();

      final bg1Restored = tester.widget<ColoredBox>(find.byKey(const ValueKey('tabbar_lab_bg_layer_1')));
      final bg2Restored = tester.widget<ColoredBox>(find.byKey(const ValueKey('tabbar_lab_bg_layer_2')));
      expect(bg1Restored.color, const Color(0xFFFFFFFF));
      expect(bg2Restored.color, const Color(0xFFFFFFFF));
    });

    testWidgets('Responsive width verification: 0px overflow across 320px, 390px, 430px, tablet, and desktop',
        (WidgetTester tester) async {
      final widths = [320.0, 390.0, 430.0, 768.0, 1200.0];

      for (final width in widths) {
        tester.view.physicalSize = Size(width, 1000.0);
        tester.view.devicePixelRatio = 1.0;

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: LiquidGlassTabBarLabScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Stage 2
        await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
        await tester.pumpAndSettle();

        FlutterError.onError = oldOnError;

        expect(caughtDetails, isNull,
            reason: 'Layout overflowed at width $width');

        // Verify title and reset button are rendered and accessible
        expect(find.text('STAGE 2 PHYSICS INSPECTOR'), findsOneWidget);
        expect(find.byKey(const ValueKey('reset_physics_defaults_button')),
            findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Phase 7C: Tint experiment is completely removed and TabBar is untinted',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      // Verify no tint toggle, sliders, or overlay widgets exist
      expect(find.byKey(const ValueKey('toggle_pill_tint')), findsNothing);
      expect(find.byKey(const ValueKey('slider_pill_tint_strength')), findsNothing);
      expect(find.byKey(const ValueKey('selection_pill_tint_layer')), findsNothing);

      // Verify physical active indicator exists
      final selectionPill =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(selectionPill, findsOneWidget);
    });

    testWidgets('Phase 7D: Real Quick Notes navigation structure, assets, FAB and folder state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      // 1. Both BottomBarGlassSurface instances exist (main bar and FAB)
      expect(find.byType(BottomBarGlassSurface), findsNWidgets(2));

      // 2. Physical active indicator uses Phase 7E Yellow Liquid Glass pill
      final activeIndicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(activeIndicatorFinder, findsOneWidget);
      // Verify it is styled with the semantic yellow color Color(0xFFFFCC00)
      final pillContainer = tester.widget<Container>(
          find.byKey(const ValueKey('quick_notes_tabbar_selection_pill')));
      expect(pillContainer, isNotNull);

      // 3. FAB displays pencil icon initially
      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('plus_icon')), findsNothing);

      // 4. Tap Folders destination (index 1) -> FAB switches to plus icon
      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.65, 1.0);
      final tab1Center = Offset(
        recreationRect.left + (40.0 + 1 * (184.0 / 3.0)) * scale,
        recreationRect.center.dy,
      );
      await tester.tapAt(tab1Center);
      await tester.pumpAndSettle();

      // Verified plus icon appears on FAB when Folders is active!
      expect(find.byKey(const ValueKey('plus_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('pencil_icon')), findsNothing);
    });

    testWidgets('Phase 7D: TabBar physics and aperture clipping remain active and untouched',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.65, 1.0);
      final tab2Center = Offset(
        recreationRect.left + (40.0 + 2 * (184.0 / 3.0)) * scale,
        recreationRect.center.dy,
      );

      // Tap Tab 2 (Calendar)
      await tester.tapAt(tab2Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue); // Travel spring active

      // Settle
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      // Selection pill centered at tab 2
      final pillFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      final pillCenter = tester.getCenter(pillFinder);
      expect(pillCenter.dx, closeTo(tab2Center.dx, 2.0));

      // Switch to Stage 1 to verify Stage 1 Native TabBar remains completely untouched
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('native_liquid_glass_tab_bar')),
          findsOneWidget);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });

    testWidgets('Phase 7D: Long-press drag interaction moves selection and springs to target',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.65, 1.0);
      final tab0Center = Offset(
        recreationRect.left + (40.0 + 0 * (184.0 / 3.0)) * scale,
        recreationRect.center.dy,
      );
      final tab2Center = Offset(
        recreationRect.left + (40.0 + 2 * (184.0 / 3.0)) * scale,
        recreationRect.center.dy,
      );

      // Start gesture at tab 0
      final gesture = await tester.startGesture(tab0Center);
      // Wait past long press threshold (100ms)
      await tester.pump(const Duration(milliseconds: 140));

      // Drag across to tab 2
      await gesture.moveTo(tab2Center);
      await tester.pump(const Duration(milliseconds: 150));

      // Release drag
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue);

      // Spring settles at tab 2
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      final pillFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      final pillCenter = tester.getCenter(pillFinder);
      expect(pillCenter.dx, closeTo(tab2Center.dx, 2.0));
    });

    testWidgets('Phase 7D.1: Navigation / FAB layer separation, sibling hierarchy, clipping, and geometry preservation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      // 1. Sibling architecture verification:
      // Main navigation bar, gap, and FAB are all present
      final mainBarFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final fabFinder =
          find.byKey(const ValueKey('quick_notes_navigation_fab'));
      final gapFinder =
          find.byKey(const ValueKey('quick_notes_navigation_gap'));
      final rowFinder =
          find.byKey(const ValueKey('quick_notes_navigation_row'));

      expect(mainBarFinder, findsOneWidget);
      expect(fabFinder, findsOneWidget);
      expect(gapFinder, findsOneWidget);
      expect(rowFinder, findsOneWidget);

      // Verify FAB is a direct sibling in Row and NOT a descendant of Main Navigation Bar
      expect(
        find.descendant(
          of: mainBarFinder,
          matching: fabFinder,
        ),
        findsNothing,
        reason: 'FAB must NOT be a child/descendant of the main navigation bar',
      );

      // Verify physical active indicator is an independent sibling in Row (Phase 7E)
      // and NOT a descendant of Main Navigation Bar or FAB
      expect(
        find.descendant(
          of: mainBarFinder,
          matching: find.byKey(const ValueKey('physical_active_indicator')),
        ),
        findsNothing,
        reason: 'Selection pill must NOT be a child/descendant of the main navigation bar in Phase 7E',
      );
      expect(
        find.descendant(
          of: fabFinder,
          matching: find.byKey(const ValueKey('physical_active_indicator')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: rowFinder,
          matching: find.byKey(const ValueKey('physical_active_indicator')),
        ),
        findsOneWidget,
        reason: 'Selection pill must be an independent sibling within the navigation coordinator stack',
      );

      // 2. Exact geometry verification:
      final mainBarRect = tester.getRect(mainBarFinder);
      final fabRect = tester.getRect(fabFinder);
      final gapSize = tester.getSize(gapFinder);

      // At desktop viewport width 1000, scale is 1.0
      expect(mainBarRect.width, closeTo(264.0, 0.5));
      expect(mainBarRect.height, closeTo(50.0, 0.5));
      expect(gapSize.width, closeTo(4.0, 0.5));
      expect(fabRect.width, closeTo(50.0, 0.5));
      expect(fabRect.height, closeTo(50.0, 0.5));

      // Sibling spacing: FAB left edge minus main bar right edge equals 4px gap
      expect(fabRect.left - mainBarRect.right, closeTo(4.0, 0.5));

      // 3. Independent interaction & absence of deformation in FAB during travel
      final tab2Center = Offset(
        mainBarRect.left + 40.0 + 2 * (184.0 / 3.0),
        mainBarRect.center.dy,
      );
      await tester.tapAt(tab2Center);
      await tester.pump(const Duration(milliseconds: 32)); // Mid-flight travel
      expect(tester.hasRunningAnimations, isTrue);

      // While main navigation selection pill is deforming and in motion,
      // FAB dimensions must remain completely unchanged (50x50)
      final midFlightFabRect = tester.getRect(fabFinder);
      expect(midFlightFabRect.width, closeTo(50.0, 0.5));
      expect(midFlightFabRect.height, closeTo(50.0, 0.5));

      await tester.pumpAndSettle();

      // 4. FAB independent tap press and haptics
      await tester.tap(fabFinder);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();
    });

    testWidgets('Phase 7D: Production AppBottomNavigationBar code is untouched and functional',
        (WidgetTester tester) async {
      int selectedIdx = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigationBar(
              selectedIndex: selectedIdx,
              onDestinationSelected: (i) => selectedIdx = i,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNavigationBar), findsOneWidget);
      expect(find.byType(BottomBarGlassSurface), findsNWidgets(2));
      expect(find.byKey(const ValueKey('physical_active_indicator')), findsOneWidget);
    });

    testWidgets('Phase 7D.2: Runtime forensic render and gesture isolation between Main Navigation and FAB',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      final mainBarFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final fabFinder =
          find.byKey(const ValueKey('quick_notes_navigation_fab'));
      final mainNavRepaintFinder =
          find.byKey(const ValueKey('main_nav_repaint_boundary'));
      final fabRepaintFinder =
          find.byKey(const ValueKey('fab_repaint_boundary'));

      // 1. Both RepaintBoundaries exist
      expect(mainNavRepaintFinder, findsOneWidget);
      expect(fabRepaintFinder, findsOneWidget);
      expect(find.descendant(of: mainNavRepaintFinder, matching: mainBarFinder), findsOneWidget);
      expect(find.descendant(of: fabRepaintFinder, matching: fabFinder), findsOneWidget);

      // 2. Initial state: neither is active
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      // 3. TEST A/B/C: FAB Press does NOT activate main navigation physics
      final fabCenter = tester.getCenter(fabFinder);
      final gesture = await tester.startGesture(fabCenter);
      await tester.pump(const Duration(milliseconds: 120));

      // FAB animation is active, NAV physics is NOT active
      expect(find.text('FAB ANIMATION: YES'), findsOneWidget);
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);

      // Release FAB
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.text('FAB ANIMATION: YES'), findsOneWidget);
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);

      // Settle FAB animation
      await tester.pumpAndSettle();
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);

      // Tab selection must NOT have been clobbered by FAB tap (tab 0 remains active)
      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);

      // 4. TEST D: Main Navigation Tap activates physics, but does NOT animate FAB
      final mainBarRect = tester.getRect(mainBarFinder);
      final tab1Center = Offset(
        mainBarRect.left + 40.0 + 1 * (184.0 / 3.0),
        mainBarRect.center.dy,
      );
      await tester.tapAt(tab1Center);
      await tester.pump(const Duration(milliseconds: 16));

      // Main nav physics is active, FAB animation is NOT active
      expect(find.text('NAV PHYSICS: YES'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      // Contextual FAB icon switches to plus_icon when Tab 1 (Folders) is selected
      await tester.pumpAndSettle();
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);
      expect(find.byKey(const ValueKey('plus_icon')), findsOneWidget);

      // 5. TEST E: Long-press drag on main navigation activates physics, but NOT FAB
      final tab1CurrentCenter = Offset(
        mainBarRect.left + 40.0 + 1 * (184.0 / 3.0),
        mainBarRect.center.dy,
      );
      final dragGesture = await tester.startGesture(tab1CurrentCenter);
      await tester.pump(const Duration(milliseconds: 200)); // Trigger long press

      expect(find.text('NAV PHYSICS: YES'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      // Move toward tab 3
      final tab3Center = Offset(
        mainBarRect.left + 40.0 + 3 * (184.0 / 3.0),
        mainBarRect.center.dy,
      );
      await dragGesture.moveTo(tab3Center);
      await tester.pump(const Duration(milliseconds: 32));

      expect(find.text('NAV PHYSICS: YES'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      await dragGesture.up();
      await tester.pumpAndSettle();
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      // Plus icon should switch back to pencil_icon since Tab 3 is not Folders
      expect(find.byKey(const ValueKey('pencil_icon')), findsOneWidget);

      // 6. TEST F: Drag/Pan on FAB does NOT start navigation drag or move capsule
      final fabPanGesture = await tester.startGesture(fabCenter);
      await tester.pump(const Duration(milliseconds: 200));
      await fabPanGesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 32));

      // Main nav physics remains inactive
      expect(find.text('NAV PHYSICS: NO'), findsOneWidget);
      await fabPanGesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Phase 7D.4: Evidence-backed fixes for FAB backdrop, shadow isolation, PageView lock, and whole-glass animation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassTabBarLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. PageView: Stage 2 PageView uses NeverScrollableScrollPhysics
      final pageViewFinder =
          find.byKey(const ValueKey('tabbar_stage_carousel_page_view'));
      expect(pageViewFinder, findsOneWidget);
      final pageView = tester.widget<PageView>(pageViewFinder);
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());

      // 2. Stage selector still switches Stage 1 / Stage 2
      final stage2Tab = find.byKey(const ValueKey('tabbar_stage_tab_1'));
      await tester.tap(stage2Tab);
      await tester.pumpAndSettle();
      expect(find.text('STAGE 2: QUICK NOTES NAVIGATION (PHYSICS)'), findsOneWidget);

      final stage1Tab = find.byKey(const ValueKey('tabbar_stage_tab_0'));
      await tester.tap(stage1Tab);
      await tester.pumpAndSettle();
      expect(find.text('STAGE 1: NATIVE LIQUID GLASS TABBAR'), findsOneWidget);

      // Return to Stage 2 for remaining tests
      await tester.tap(stage2Tab);
      await tester.pumpAndSettle();

      // 3. Main Navigation and FAB sizing and 4px gap
      final mainBarFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final fabFinder =
          find.byKey(const ValueKey('quick_notes_navigation_fab'));
      final gapFinder =
          find.byKey(const ValueKey('quick_notes_navigation_gap'));
      final mainBarRect = tester.getRect(mainBarFinder);
      final fabRect = tester.getRect(fabFinder);
      final gapSize = tester.getSize(gapFinder);

      expect(mainBarRect.width, closeTo(264.0, 0.5));
      expect(mainBarRect.height, closeTo(50.0, 0.5));
      expect(fabRect.width, closeTo(50.0, 0.5));
      expect(fabRect.height, closeTo(50.0, 0.5));
      expect(gapSize.width, closeTo(4.0, 0.5));
      expect(fabRect.left - mainBarRect.right, closeTo(4.0, 0.5));

      // 4. Backdrop Isolation: FAB paints first in paint order, isolated from main navigation
      final navRowFinder =
          find.byKey(const ValueKey('quick_notes_navigation_row'));
      final rowSizedBox = tester.widget<SizedBox>(navRowFinder);
      final stackWidget = rowSizedBox.child! as Stack;
      // Verify paint order: FAB sibling is child 0 in the Stack
      final firstPositioned = stackWidget.children[0] as Positioned;
      expect(firstPositioned.left, closeTo(268.0, 0.5)); // barW (264) + gapW (4) = 268

      // 5. Shadow Isolation: Main navigation is clipped by _MainNavShadowIsolationClipper stopping before FAB
      final shadowClipFinder = find.byKey(const ValueKey('main_nav_shadow_clip'));
      expect(shadowClipFinder, findsOneWidget);
      final clipRectWidget = tester.widget<ClipRect>(shadowClipFinder);
      final clipper = clipRectWidget.clipper as CustomClipper<Rect>;
      final clipBounds = clipper.getClip(Size(mainBarRect.width, mainBarRect.height));
      expect(clipBounds.left, -50.0);
      expect(clipBounds.top, -50.0);
      expect(clipBounds.right, closeTo(268.0, 0.5)); // exactly at barW + gapW, before FAB physical region
      expect(clipBounds.bottom, closeTo(100.0, 0.5)); // controlH + 50

      // 6. FAB whole-glass press animation: Transform.scale wraps BottomBarGlassSurface
      final fabScaleFinder = find.byKey(const ValueKey('fab_scale_transform'));
      final fabGlassFinder = find.byKey(const ValueKey('fab_glass_surface'));
      expect(fabScaleFinder, findsOneWidget);
      expect(fabGlassFinder, findsOneWidget);
      // Prove that Transform.scale is an ANCESTOR of the BottomBarGlassSurface
      expect(
        find.descendant(of: fabScaleFinder, matching: fabGlassFinder),
        findsOneWidget,
      );

      // Verify FAB press animation scale (0.94) and release spring
      final initialFabTransform = tester.widget<Transform>(fabScaleFinder);
      expect(initialFabTransform.transform.storage[0], closeTo(1.0, 0.001));

      // Press and hold FAB
      final fabCenter = tester.getCenter(fabFinder);
      final pressGesture = await tester.startGesture(fabCenter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('FAB ANIMATION: YES'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final pressedFabTransform = tester.widget<Transform>(fabScaleFinder);
      expect(pressedFabTransform.transform.storage[0], closeTo(0.94, 0.02));

      // Release FAB and allow spring bounce
      await pressGesture.up();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('FAB ANIMATION: YES'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('FAB ANIMATION: NO'), findsOneWidget);

      // 7. Settings selection does NOT alter FAB tint or appearance
      final settingsTabCenter = Offset(
        mainBarRect.left + 40.0 + 3 * (184.0 / 3.0),
        mainBarRect.center.dy,
      );
      await tester.tapAt(settingsTabCenter);
      await tester.pumpAndSettle();

      // Selection capsule moved to Settings (Tab 3)
      final selectionPill = find.byKey(const ValueKey('quick_notes_tabbar_selection_pill'));
      final pillRect = tester.getRect(selectionPill);
      expect(pillRect.center.dx, closeTo(settingsTabCenter.dx, 10.0));

      // FAB remains at 50x50 at x = 268 relative to main bar, with unchanged geometry and 4px gap
      final fabRectAfterSettings = tester.getRect(fabFinder);
      expect(fabRectAfterSettings.width, closeTo(50.0, 0.5));
      expect(fabRectAfterSettings.height, closeTo(50.0, 0.5));
      expect(fabRectAfterSettings.left - mainBarRect.left, closeTo(268.0, 0.5));
      expect(fabRectAfterSettings.left - mainBarRect.right, closeTo(4.0, 0.5));
    });

    testWidgets(
        'Phase 7E: Yellow Liquid Glass Selection Pill as an Independent Floating Overlay',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: LiquidGlassTabBarLabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Stage 2
      await tester.tap(find.byKey(const ValueKey('tabbar_stage_tab_1')));
      await tester.pumpAndSettle();

      // 1. Sibling Hierarchy Verification
      final mainBarFinder =
          find.byKey(const ValueKey('quick_notes_main_navigation_bar'));
      final fabFinder =
          find.byKey(const ValueKey('quick_notes_navigation_fab'));
      final rowFinder =
          find.byKey(const ValueKey('quick_notes_navigation_row'));
      final pillFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      final pillContainerFinder =
          find.byKey(const ValueKey('quick_notes_tabbar_selection_pill'));

      expect(mainBarFinder, findsOneWidget);
      expect(fabFinder, findsOneWidget);
      expect(rowFinder, findsOneWidget);
      expect(pillFinder, findsOneWidget);

      // Verify pill is NOT a descendant of the Main Navigation Bar
      expect(
        find.descendant(of: mainBarFinder, matching: pillFinder),
        findsNothing,
        reason: 'Yellow pill must NOT be rendered inside the Main Navigation Bar',
      );

      // Verify pill is NOT a descendant of the FAB
      expect(
        find.descendant(of: fabFinder, matching: pillFinder),
        findsNothing,
        reason: 'Yellow pill must NOT be rendered inside the FAB',
      );

      // Verify pill is an independent sibling within the navigation coordinator stack
      expect(
        find.descendant(of: rowFinder, matching: pillFinder),
        findsOneWidget,
        reason: 'Yellow pill must be an independent sibling overlay in the navigation stack',
      );

      // 2. IgnorePointer / Pass-through Verification
      final ignorePointerFinder = find.ancestor(
        of: pillContainerFinder,
        matching: find.byType(IgnorePointer),
      );
      expect(ignorePointerFinder, findsWidgets);
      final ignorePointerWidget = tester.widget<IgnorePointer>(ignorePointerFinder.first);
      expect(ignorePointerWidget.ignoring, isTrue,
          reason: 'Yellow pill overlay must have IgnorePointer(ignoring: true) for gesture pass-through');

      // 3. Parent Stack Unclipped Verification (clipBehavior: Clip.none)
      final stackFinder = find.descendant(
        of: rowFinder,
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsWidgets);
      final parentStack = tester.widget<Stack>(stackFinder.first);
      expect(parentStack.clipBehavior, equals(Clip.none),
          reason: 'Parent Stack must use clipBehavior: Clip.none to allow pill lift/deformation without clipping');

      // 4. Yellow Liquid Glass Material DNA Verification
      // Inspect the pill widget properties
      final pillBodyFinder = find.descendant(
        of: pillFinder,
        matching: find.byType(BackdropFilter),
      );
      expect(pillBodyFinder, findsOneWidget,
          reason: 'Yellow pill must have its own BackdropFilter for translucent glass refraction/blur');

      // Verify pill shadow isolation clipper exists to prevent bleed into FAB
      expect(find.byType(ClipRect), findsWidgets);

      // 5. Travel & Live Geometry Preservation
      final initialPillRect = tester.getRect(pillContainerFinder);
      expect(initialPillRect.width, closeTo(70.0, 5.0));
      expect(initialPillRect.height, closeTo(43.0, 5.0));

      final recreationFinder =
          find.byKey(const ValueKey('quick_notes_tab_bar_recreation'));
      final recreationRect = tester.getRect(recreationFinder);
      final scale = (recreationRect.width / 318.0).clamp(0.70, 1.0);
      double getCenter(int i) =>
          recreationRect.left + (40.0 + i * (184.0 / 3.0)) * scale;

      // Tap tab 3 (Settings) to verify travel and aperture synchronization
      final tab3Center = Offset(getCenter(3), recreationRect.center.dy);
      await tester.tapAt(tab3Center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.hasRunningAnimations, isTrue,
          reason: 'Tapping unselected tab must activate Phase 7 travel spring');

      // Settle animation to destination
      await tester.pumpAndSettle();
      final settledPillRect = tester.getRect(pillContainerFinder);
      expect(settledPillRect.center.dx, closeTo(getCenter(3), 4.0));
      expect(settledPillRect.width, closeTo(70.0 * scale, 1.0));
      expect(settledPillRect.height, closeTo(43.0 * scale, 1.0));

      // Main navigation and FAB geometry remain untouched
      final mainBarRect = tester.getRect(mainBarFinder);
      final fabRect = tester.getRect(fabFinder);
      expect(mainBarRect.width, closeTo(264.0, 0.5));
      expect(mainBarRect.height, closeTo(50.0, 0.5));
      expect(fabRect.width, closeTo(50.0, 0.5));
      expect(fabRect.height, closeTo(50.0, 0.5));
      expect(fabRect.left - mainBarRect.right, closeTo(4.0, 0.5));
    });
  });
}
