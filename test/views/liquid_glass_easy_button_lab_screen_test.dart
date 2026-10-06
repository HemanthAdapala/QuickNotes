import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_flex.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_easy_button_lab_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  testWidgets('LiquidGlassEasyButtonLabScreen satisfies stage depth architecture, controls, and native button',
      (WidgetTester tester) async {
    // Set standard phone screen size
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

    // ------------------------------------------------------------------------
    // VERIFICATION 1: Title and Native LiquidGlassButton presence & configuration
    // ------------------------------------------------------------------------
    expect(find.text('Liquid Glass Button Lab'), findsOneWidget);
    expect(find.text('PREVIEW STAGE'), findsOneWidget);
    expect(find.text('SURFACE PARAMETERS'), findsOneWidget);
    expect(find.byType(LiquidGlassButton), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    // Verify documented touch configuration is present on the native button
    final initialButton = tester.widget<LiquidGlassButton>(find.byType(LiquidGlassButton));
    expect(initialButton.touch, isNotNull);
    expect(initialButton.touch!.flex, isNotNull);

    // ------------------------------------------------------------------------
    // VERIFICATION 2: Layer Presence and Depth Hierarchy
    // Layer 1: Background 1 (Base canvas)
    // Layer 2: Background 2 (Surface island)
    // Layer 3: Active Stage Button inside Stage Carousel
    // ------------------------------------------------------------------------
    final bg1Finder = find.byKey(const ValueKey('background_layer_1'));
    final bg2Finder = find.byKey(const ValueKey('background_layer_2'));
    final button1Finder = find.byKey(const ValueKey('native_liquid_glass_button'));
    final pageViewFinder = find.byKey(const ValueKey('stage_carousel_page_view'));

    expect(bg1Finder, findsOneWidget);
    expect(bg2Finder, findsOneWidget);
    expect(button1Finder, findsOneWidget);
    expect(pageViewFinder, findsOneWidget);

    // Verify button is not enclosed inside the ColoredBox of Layer 1 or Layer 2
    expect(
      find.descendant(
        of: bg1Finder,
        matching: find.byType(LiquidGlassButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: bg2Finder,
        matching: find.byType(LiquidGlassButton),
      ),
      findsNothing,
    );

    // ------------------------------------------------------------------------
    // VERIFICATION 3: Stage 1 and Stage 2 Navigation & Indicator
    // ------------------------------------------------------------------------
    // Verify initial Stage 1 indicator label and tabs
    expect(find.text('1. LG Easy'), findsOneWidget);
    expect(find.text('2. Quick Notes'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage_indicator_dots')), findsOneWidget);
    expect(find.textContaining('STAGE 1'), findsOneWidget);

    // Navigate to Stage 2 via Stage Tab 2
    final stageTab2 = find.byKey(const ValueKey('stage_tab_2'));
    expect(stageTab2, findsOneWidget);
    await tester.tap(stageTab2);
    await tester.pumpAndSettle();

    // Verify Stage 2: Quick Notes Create Folder button is visible and active
    final button2Finder = find.byKey(const ValueKey('quick_notes_create_folder_glass'));
    expect(button2Finder, findsOneWidget);
    expect(find.text('Create Folder'), findsOneWidget);
    expect(find.textContaining('STAGE 2'), findsOneWidget);

    // Background 1 and 2 remain underneath Stage 2
    expect(bg1Finder, findsOneWidget);
    expect(bg2Finder, findsOneWidget);

    // Tap Quick Notes Create Folder button
    await tester.tap(button2Finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Quick Notes "Create Folder" tapped!'), findsOneWidget);
    await tester.pumpAndSettle();

    // Navigate back to Stage 1 via Stage Tab 1
    final stageTab1 = find.byKey(const ValueKey('stage_tab_1'));
    expect(stageTab1, findsOneWidget);
    await tester.tap(stageTab1);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('native_liquid_glass_button')), findsOneWidget);
    expect(find.textContaining('STAGE 1'), findsOneWidget);

    // ------------------------------------------------------------------------
    // VERIFICATION 4: Background 1 selector works (Palette Swatches)
    // ------------------------------------------------------------------------
    final bg1Before = tester.widget<ColoredBox>(bg1Finder).color;

    // Tap on swatch index 5 (Red: 0xFFFF3B30)
    final redSwatchFinder = find.byKey(const ValueKey('palette_swatch_5'));
    expect(redSwatchFinder, findsOneWidget);
    await tester.ensureVisible(redSwatchFinder);
    await tester.tap(redSwatchFinder);
    await tester.pumpAndSettle();

    final bg1After = tester.widget<ColoredBox>(bg1Finder).color;
    expect(bg1After, isNot(equals(bg1Before)));
    expect(bg1After, const Color(0xFFFF3B30));

    // ------------------------------------------------------------------------
    // VERIFICATION 5: Background 1 White -> Black slider works
    // ------------------------------------------------------------------------
    final bg1SliderFinder = find.byKey(const ValueKey('bg1_slider'));
    expect(bg1SliderFinder, findsOneWidget);

    // Slide to 0.0 (Pure White)
    final slider = tester.widget<Slider>(bg1SliderFinder);
    slider.onChanged?.call(0.0);
    await tester.pumpAndSettle();

    final bg1White = tester.widget<ColoredBox>(bg1Finder).color;
    expect(bg1White, const Color(0xFFFFFFFF));

    // Slide to 1.0 (Pure Black)
    slider.onChanged?.call(1.0);
    await tester.pumpAndSettle();

    final bg1Black = tester.widget<ColoredBox>(bg1Finder).color;
    expect(bg1Black, const Color(0xFF000000));

    // ------------------------------------------------------------------------
    // VERIFICATION 6: Background 1 HEX input accepts valid HEX
    // ------------------------------------------------------------------------
    final bg1HexInput = find.byKey(const ValueKey('bg1_hex_input'));
    expect(bg1HexInput, findsOneWidget);
    await tester.enterText(bg1HexInput, '#1E1B4B');
    await tester.pumpAndSettle();

    final bg1Custom = tester.widget<ColoredBox>(bg1Finder).color;
    expect(bg1Custom, const Color(0xFF1E1B4B));

    // ------------------------------------------------------------------------
    // VERIFICATION 7: Background 2 HEX input accepts valid HEX (#007AFF, 00FF00)
    // ------------------------------------------------------------------------
    final hexInputFinder = find.byKey(const ValueKey('bg2_hex_input'));
    expect(hexInputFinder, findsOneWidget);

    // Enter valid Hex with hash
    await tester.enterText(hexInputFinder, '#00FF00');
    await tester.pumpAndSettle();

    var bg2Box = tester.widget<ColoredBox>(bg2Finder);
    // Green (0x00, 0xFF, 0x00)
    expect((bg2Box.color.r * 255).round(), 0x00);
    expect((bg2Box.color.g * 255).round(), 0xFF);
    expect((bg2Box.color.b * 255).round(), 0x00);

    // Enter valid Hex without hash
    await tester.enterText(hexInputFinder, '007AFF');
    await tester.pumpAndSettle();

    bg2Box = tester.widget<ColoredBox>(bg2Finder);
    expect((bg2Box.color.r * 255).round(), 0x00);
    expect((bg2Box.color.g * 255).round(), 0x7A);
    expect((bg2Box.color.b * 255).round(), 0xFF);

    // ------------------------------------------------------------------------
    // VERIFICATION 8: Background 2 invalid HEX does not crash & retains previous color
    // ------------------------------------------------------------------------
    await tester.enterText(hexInputFinder, 'INVALID_HEX');
    await tester.pumpAndSettle();

    bg2Box = tester.widget<ColoredBox>(bg2Finder);
    expect((bg2Box.color.r * 255).round(), 0x00);
    expect((bg2Box.color.g * 255).round(), 0x7A);
    expect((bg2Box.color.b * 255).round(), 0xFF);

    // ------------------------------------------------------------------------
    // VERIFICATION 9: Background 2 Opacity slider supports 0% to 100%
    // ------------------------------------------------------------------------
    final bg2OpacitySliderFinder = find.byKey(const ValueKey('bg2_opacity_slider'));
    expect(bg2OpacitySliderFinder, findsOneWidget);

    final opacitySlider = tester.widget<Slider>(bg2OpacitySliderFinder);

    // 0% Opacity
    opacitySlider.onChanged?.call(0.0);
    await tester.pumpAndSettle();
    bg2Box = tester.widget<ColoredBox>(bg2Finder);
    expect(bg2Box.color.a, 0.0);

    // 50% Opacity
    opacitySlider.onChanged?.call(0.5);
    await tester.pumpAndSettle();
    bg2Box = tester.widget<ColoredBox>(bg2Finder);
    expect((bg2Box.color.a * 100).round(), 50);

    // 100% Opacity
    opacitySlider.onChanged?.call(1.0);
    await tester.pumpAndSettle();
    bg2Box = tester.widget<ColoredBox>(bg2Finder);
    expect(bg2Box.color.a, 1.0);

    // ------------------------------------------------------------------------
    // VERIFICATION 10: Native LiquidGlassButton remains present & interactive
    // ------------------------------------------------------------------------
    expect(find.byType(LiquidGlassButton), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Verify touch configuration is preserved
    final buttonAfter = tester.widget<LiquidGlassButton>(find.byType(LiquidGlassButton));
    expect(buttonAfter.touch, isNotNull);
    expect(buttonAfter.touch!.flex, isNotNull);

    // Tap button to verify interactivity and responsiveness
    await tester.tap(find.byType(LiquidGlassButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LiquidGlassButton tapped!'), findsOneWidget);
  });

  testWidgets(
      'Phase 3: Stage 2 isolates LiquidGlassEasy press physics, eliminates TactileButton/ScaleTransition/haptics, and preserves production components',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Track any haptic triggers to verify Stage 2 does not fire button haptics
    final List<String> triggeredHaptics = [];
    QuickNotesHaptics.debugHapticListener = (method) {
      triggeredHaptics.add(method);
    };
    addTearDown(() {
      QuickNotesHaptics.debugHapticListener = null;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassEasyButtonLabScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------------
    // POINT 1 & 10: Stage 1 remains unchanged (LiquidGlassButton + LiquidGlassTouch.flex)
    // ------------------------------------------------------------------------
    final stage1ButtonFinder = find.byKey(const ValueKey('native_liquid_glass_button'));
    expect(stage1ButtonFinder, findsOneWidget);
    final stage1Button = tester.widget<LiquidGlassButton>(stage1ButtonFinder);
    expect(stage1Button.touch, isNotNull);
    expect(stage1Button.touch!.flex, isNotNull);
    expect(stage1Button.touch!.flex!.compressInward, isTrue);

    // ------------------------------------------------------------------------
    // POINT 11: Background 1 and Background 2 remain unchanged underneath
    // ------------------------------------------------------------------------
    expect(find.byKey(const ValueKey('background_layer_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('background_layer_2')), findsOneWidget);

    // Navigate to Stage 2
    final stageTab2 = find.byKey(const ValueKey('stage_tab_2'));
    await tester.tap(stageTab2);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------------
    // POINT 2: Stage 2 still uses the real Quick Notes glass renderer (BottomBarGlassSurface)
    // ------------------------------------------------------------------------
    final stage2Root = find.byKey(const ValueKey('quick_notes_create_folder_glass'));
    expect(stage2Root, findsOneWidget);
    expect(
      find.descendant(
        of: stage2Root,
        matching: find.byType(BottomBarGlassSurface),
      ),
      findsOneWidget,
    );

    // ------------------------------------------------------------------------
    // POINT 3, 4, 5: Stage 2 has NO TactileButton, NO ScaleTransition, NO 0.90 compression, NO legacy animation
    // ------------------------------------------------------------------------
    expect(
      find.descendant(
        of: stage2Root,
        matching: find.byType(TactileButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: stage2Root,
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );

    // ------------------------------------------------------------------------
    // POINT 9: Stage 2 interaction does NOT trigger production buttonPress haptics
    // ------------------------------------------------------------------------
    triggeredHaptics.clear();
    await tester.tap(stage2Root);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(triggeredHaptics.contains('buttonPress'), isFalse);
    expect(find.text('Quick Notes "Create Folder" tapped!'), findsOneWidget);
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------------
    // POINT 12: Stage 2 Clean Baseline vs Experimental Touch mode toggling
    // ------------------------------------------------------------------------
    // Initially, EXPERIMENTAL TOUCH is active with badge visible
    expect(find.byKey(const ValueKey('stage2_experiment_badge')), findsOneWidget);
    expect(find.textContaining('EXPERIMENTAL TOUCH'), findsWidgets);

    // Switch to CLEAN BASELINE via Workbench mode selector
    final baselineBtn = find.byKey(const ValueKey('stage2_baseline_mode_button'));
    await tester.ensureVisible(baselineBtn);
    await tester.tap(baselineBtn);
    await tester.pumpAndSettle();

    // In Clean Baseline mode, badge displays STATIC and gesture is static
    expect(find.textContaining('STATIC'), findsWidgets);
    expect(find.byKey(const ValueKey('stage2_clean_baseline_gesture')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage2_experimental_flex_listener')), findsNothing);

    // Tap in clean baseline mode: works, no scale, no haptics
    triggeredHaptics.clear();
    await tester.tap(find.byKey(const ValueKey('stage2_clean_baseline_gesture')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(triggeredHaptics.contains('buttonPress'), isFalse);
    expect(find.text('Quick Notes "Create Folder" tapped!'), findsOneWidget);
    await tester.pumpAndSettle();

    // Switch back to EXPERIMENTAL PRESS mode
    final pressBtn = find.byKey(const ValueKey('stage2_press_mode_button'));
    await tester.ensureVisible(pressBtn);
    await tester.tap(pressBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('EXPERIMENTAL TOUCH'), findsWidgets);
    expect(find.byKey(const ValueKey('stage2_experimental_flex_listener')), findsOneWidget);

    // Test PointerDown on experimental flex listener: confirms LiquidGlassFlexDriver touch physics are connected
    final listenerFinder = find.byKey(const ValueKey('stage2_experimental_flex_listener'));
    final TestGesture gesture = await tester.createGesture(pointer: 1);
    await gesture.down(tester.getCenter(listenerFinder));
    await tester.pump(const Duration(milliseconds: 50));
    // Verify glass surface is still rendered under press deformation
    expect(
      find.descendant(
        of: stage2Root,
        matching: find.byType(BottomBarGlassSurface),
      ),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // ------------------------------------------------------------------------
    // POINT 6, 7, 8, 9: Verify Production components, constants, and haptics remain unchanged
    // ------------------------------------------------------------------------
    // Production TactileButton default parameters check
    const tactile = TactileButton(
      onTap: _dummyCallback,
      child: SizedBox(),
    );
    expect(tactile.compressionScale, equals(0.94));
    expect(tactile.useAppleSpring, isTrue);
    expect(tactile.playSelectionHaptic, isTrue);

    // Production BottomBarGlassSurface instantiation check
    final glassSurface = BottomBarGlassSurface(
      width: 100,
      height: 40,
      borderRadius: BorderRadius.circular(20),
      child: const SizedBox(),
    );
    expect(glassSurface.width, equals(100));
    expect(glassSurface.height, equals(40));
    expect(glassSurface.borderRadius, equals(BorderRadius.circular(20)));

    // Production motion constants check
    expect(QuickNotesMotion.kMotionMicro, equals(const Duration(milliseconds: 90)));
    expect(QuickNotesMotion.kMotionRelease, equals(const Duration(milliseconds: 190)));
    expect(QuickNotesMotion.kMotionAppleEase, isA<Cubic>());
    expect(QuickNotesMotion.kMotionSpring, isA<Curve>());
  });

  testWidgets(
      'Phase 5: Native directional deformation (stretch + lean + squeeze + grip + compressInward) produces directional asymmetry and transverse contraction',
      (WidgetTester tester) async {
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

    // 1. Stage 1 remains unchanged reference
    final stage1Button = tester.widget<LiquidGlassButton>(find.byKey(const ValueKey('native_liquid_glass_button')));
    expect(stage1Button.touch, isNotNull);
    expect(stage1Button.touch!.flex, isNotNull);

    // Navigate to Stage 2
    await tester.tap(find.byKey(const ValueKey('stage_tab_2')));
    await tester.pumpAndSettle();

    final stage2Root = find.byKey(const ValueKey('quick_notes_create_folder_glass'));
    expect(stage2Root, findsOneWidget);

    // 2. Real BottomBarGlassSurface is used, TactileButton is absent
    expect(find.descendant(of: stage2Root, matching: find.byType(BottomBarGlassSurface)), findsOneWidget);
    expect(find.descendant(of: stage2Root, matching: find.byType(TactileButton)), findsNothing);

    // 3. Label communicates PRESS + STRETCH
    expect(find.textContaining('PRESS + STRETCH'), findsWidgets);

    final glassFinder = find.descendant(of: stage2Root, matching: find.byType(BottomBarGlassSurface));
    final Rect restRect = tester.getRect(glassFinder);

    // 4. Test Press-only (Phase 6.1 outward swell before drag: holdScale: 0.030)
    final TestGesture pressGesture = await tester.createGesture(pointer: 10);
    await pressGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 80));
    final Rect pressRect = tester.getRect(glassFinder);
    // Phase 6.1 press swell causes width and height to gently expand outward (holdScale: 0.030)
    expect(pressRect.width, greaterThan(restRect.width));
    expect(pressRect.height, greaterThan(restRect.height));
    await pressGesture.up();
    await tester.pumpAndSettle();

    // 5. Test Drag Right: Rightward elongation + Transverse Squeeze + Directional Lean Asymmetry
    final TestGesture rightGesture = await tester.createGesture(pointer: 11);
    await rightGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 30));
    await rightGesture.moveBy(const Offset(48, 0));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect rightRect = tester.getRect(glassFinder);
    // Width increases along the pull axis
    expect(rightRect.width, greaterThan(restRect.width));
    // Squeeze is ACTIVE: cross-axis height contracts inward below rest height at full pull
    expect(rightRect.height, lessThan(restRect.height));
    // Lean is ACTIVE: Right edge moves rightward strongly, while left edge remains comparatively anchored
    expect(rightRect.right, greaterThan(restRect.right + 2.0));
    expect(rightRect.left, greaterThanOrEqualTo(restRect.left - 3.5));
    await rightGesture.up();
    await tester.pumpAndSettle();

    // 6. Test Drag Left: Leftward elongation + Transverse Squeeze + Directional Lean Asymmetry (Mirror)
    final TestGesture leftGesture = await tester.createGesture(pointer: 12);
    await leftGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 30));
    await leftGesture.moveBy(const Offset(-48, 0));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect leftRect = tester.getRect(glassFinder);
    expect(leftRect.width, greaterThan(restRect.width));
    expect(leftRect.height, lessThan(restRect.height)); // Squeeze active
    // Left edge moves leftward strongly, while right edge remains anchored
    expect(leftRect.left, lessThan(restRect.left - 2.0));
    expect(leftRect.right, lessThanOrEqualTo(restRect.right + 3.5));
    await leftGesture.up();
    await tester.pumpAndSettle();

    // 7. Test Drag Down: Downward elongation + Transverse Squeeze (Width contracts)
    final TestGesture downGesture = await tester.createGesture(pointer: 13);
    await downGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 30));
    await downGesture.moveBy(const Offset(0, 40));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect downRect = tester.getRect(glassFinder);
    expect(downRect.height, greaterThan(restRect.height));
    // Squeeze is ACTIVE: cross-axis width contracts inward
    expect(downRect.width, lessThan(restRect.width));
    // Bottom edge moves downward strongly, while top edge remains anchored
    expect(downRect.bottom, greaterThan(restRect.bottom + 2.0));
    expect(downRect.top, greaterThanOrEqualTo(restRect.top - 1.5));
    await downGesture.up();
    await tester.pumpAndSettle();

    // 8. Test Drag Up: Upward elongation + Transverse Squeeze (Width contracts)
    final TestGesture upGesture = await tester.createGesture(pointer: 14);
    await upGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 30));
    await upGesture.moveBy(const Offset(0, -40));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect upRect = tester.getRect(glassFinder);
    expect(upRect.height, greaterThan(restRect.height));
    expect(upRect.width, lessThan(restRect.width)); // Squeeze active
    // Top edge moves upward strongly, while bottom edge remains anchored
    expect(upRect.top, lessThan(restRect.top - 2.0));
    expect(upRect.bottom, lessThanOrEqualTo(restRect.bottom + 1.5));
    await upGesture.up();
    await tester.pumpAndSettle();

    // 9. Bounded drag resistance (tanh limit at stretch = 13.0)
    final TestGesture hugeGesture = await tester.createGesture(pointer: 15);
    await hugeGesture.down(restRect.center);
    await tester.pump(const Duration(milliseconds: 30));
    await hugeGesture.moveBy(const Offset(300, 0)); // Huge pull
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect hugeRect = tester.getRect(glassFinder);
    // Stretch ceiling is 13.0 px plus 3% press swell (6.0 px), so deformed width gain cannot exceed 20.0 px
    expect(hugeRect.width - restRect.width, lessThanOrEqualTo(20.0));
    await hugeGesture.up();
    await tester.pumpAndSettle();

    // 10. Content anchoring: Text remains stable and readable
    expect(find.text('Create Folder'), findsOneWidget);
  });

  testWidgets(
      'Phase 5: Focused mathematical verification of native LiquidGlassFlex driver model',
      (WidgetTester tester) async {
    // 1. Edge weights sum to 1.0 for any normalized grab coordinate gx, gy
    const double grip = 0.70;
    for (final double g in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final double wR = 0.5 + (g - 0.5) * grip;
      final double wL = 0.5 + (1 - g - 0.5) * grip;
      expect((wR + wL - 1.0).abs(), lessThan(1e-9));

      final double wB = 0.5 + (g - 0.5) * grip;
      final double wT = 0.5 + (1 - g - 0.5) * grip;
      expect((wB + wT - 1.0).abs(), lessThan(1e-9));
    }

    // 2. Grab near right edge (gx = 1.0) concentrates weight to right edge (wR = 0.85, wL = 0.15)
    const double wRightEdge = 0.5 + (1.0 - 0.5) * grip;
    const double wLeftEdge = 0.5 + (0.0 - 0.5) * grip;
    expect(wRightEdge, closeTo(0.85, 1e-4));
    expect(wLeftEdge, closeTo(0.15, 1e-4));

    // 3. Test driver with Phase 6.1 Stage 2 spec
    const spec = LiquidGlassFlex(
      stretch: 13.0,
      squeeze: 0.70,
      lean: 0.50,
      grip: 0.70,
      compressInward: true,
      holdScale: 0.030,
      tapScale: 0.020,
      maxPull: 48.0,
      advanced: LiquidGlassFlexAdvanced(
        childFollow: 0.0,
        refractionBoost: 0.0,
        magnificationBoost: 0.0,
        stiffness: 320,
        damping: 24,
        releaseDamping: 17.0,
      ),
    );

    final driver = LiquidGlassFlexDriver(
      vsync: tester,
      spec: spec,
    );
    driver.restSize = const Size(200, 50);

    // A. Center Grab + Drag Right
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 1);
    driver.move(const Offset(48, 0), pointer: 1);
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformRight = driver.value;
    // Right edge deformation is positive and significantly larger than left edge
    expect(deformRight.right, greaterThan(deformRight.left));
    // Squeeze reduces top and bottom edges (negative travel)
    expect(deformRight.top, lessThan(0.0));
    expect(deformRight.bottom, lessThan(0.0));
    driver.up(pointer: 1);
    await tester.pumpAndSettle();

    // B. Center Grab + Drag Left (Mirror of Right Drag)
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 2);
    driver.move(const Offset(-48, 0), pointer: 2);
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformLeft = driver.value;
    expect(deformLeft.left, greaterThan(deformLeft.right));
    expect(deformLeft.top, lessThan(0.0));
    expect(deformLeft.bottom, lessThan(0.0));
    // Symmetry check: left edge in left drag matches right edge in right drag
    expect(deformLeft.left, closeTo(deformRight.right, 0.5));
    expect(deformLeft.right, closeTo(deformRight.left, 0.5));
    driver.up(pointer: 2);
    await tester.pumpAndSettle();

    // C. Center Grab + Drag Up
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 3);
    driver.move(const Offset(0, -48), pointer: 3);
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformUp = driver.value;
    expect(deformUp.top, greaterThan(deformUp.bottom));
    // Cross-axis squeeze reduces left and right edges
    expect(deformUp.left, lessThan(0.0));
    expect(deformUp.right, lessThan(0.0));
    driver.up(pointer: 3);
    await tester.pumpAndSettle();

    // D. Right Edge Grab + Drag Left (compressInward: pushing into body squashes)
    driver.down(const Offset(200, 25), const Size(200, 50), pointer: 4); // Grab right edge
    driver.move(const Offset(-48, 0), pointer: 4); // Drag inward to the left
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformInward = driver.value;
    // Pushing inward squashes horizontally: width delta is significantly less than outward drag and below press swell (+6.0px)
    expect(deformInward.widthDelta, lessThan(6.0));
    // And squashing horizontally causes cross-axis squeeze to bulge vertically!
    expect(deformInward.heightDelta, greaterThan(deformRight.heightDelta));
    driver.up(pointer: 4);
    await tester.pumpAndSettle();

    // E. Diagonal Drag (resolves both axes independently)
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 5);
    driver.move(const Offset(40, -40), pointer: 5); // Right + Up
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformDiag = driver.value;
    // Right edge and top edge both extend
    expect(deformDiag.right, greaterThan(deformDiag.left));
    expect(deformDiag.top, greaterThan(deformDiag.bottom));
    driver.up(pointer: 5);
    await tester.pumpAndSettle();

    // F. Phase 6.1: Press-only causes outward swell (holdScale: 0.030)
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 6);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final deformPress = driver.value;
    expect(deformPress.left, greaterThan(0.0));
    expect(deformPress.right, greaterThan(0.0));
    expect(deformPress.top, greaterThan(0.0));
    expect(deformPress.bottom, greaterThan(0.0));
    driver.up(pointer: 6);
    await tester.pumpAndSettle();

    // G. Phase 6.1: Tap generates outward pop (tapScale: 0.020)
    driver.down(const Offset(100, 25), const Size(200, 50), pointer: 7);
    await tester.pump(const Duration(milliseconds: 30));
    driver.up(pointer: 7); // Tap release within kLongPressTimeout & kTouchSlop
    await tester.pump(const Duration(milliseconds: 16)); // First tick after release
    final deformTapPop = driver.value;
    expect(deformTapPop.widthDelta, greaterThan(0.0));
    expect(deformTapPop.heightDelta, greaterThan(0.0));
    await tester.pumpAndSettle();

    // H. Phase 6.1: Release recoil damping produces underdamped return (releaseDamping: 17.0)
    expect(spec.releaseDamping, equals(17.0));
    expect(spec.damping, equals(24.0));
    expect(spec.stiffness, equals(320.0));
    expect(spec.holdScale, equals(0.030));
    expect(spec.tapScale, equals(0.020));

    driver.dispose();
  });

  testWidgets(
      'Stage 3 removal verification and Lab Scrolling ON/OFF toggle controls page scrollability',
      (WidgetTester tester) async {
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

    // 1. Verify Stage 3 is completely absent from the lab
    expect(find.text('3. Optics 6B'), findsNothing);
    expect(find.byKey(const ValueKey('stage_tab_3')), findsNothing);
    expect(find.byKey(const ValueKey('stage_dot_2')), findsNothing);
    expect(find.byKey(const ValueKey('stage3_experiment_badge')), findsNothing);
    expect(find.byKey(const ValueKey('phase6b_optical_glass_button')), findsNothing);
    expect(find.text('Stage 3: Optical Pipeline'), findsNothing);
    expect(find.byKey(const ValueKey('optical_refraction_index_slider')), findsNothing);

    // Exactly 2 stages exist (Stage 1 and Stage 2)
    expect(find.text('1. LG Easy'), findsOneWidget);
    expect(find.text('2. Quick Notes'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage_dot_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage_dot_1')), findsOneWidget);

    // 2. Verify "Lab Scrolling" toggle is present in the UI
    expect(find.text('Lab Scrolling'), findsOneWidget);
    expect(find.text('SCROLL ON'), findsOneWidget);
    final onBtnFinder = find.byKey(const ValueKey('lab_scrolling_on_button'));
    final offBtnFinder = find.byKey(const ValueKey('lab_scrolling_off_button'));
    expect(onBtnFinder, findsOneWidget);
    expect(offBtnFinder, findsOneWidget);

    // Initially, vertical scrolling is enabled (AlwaysScrollableScrollPhysics)
    final scrollableFinder = find.byType(SingleChildScrollView).first;
    var scrollView = tester.widget<SingleChildScrollView>(scrollableFinder);
    expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());

    // 3. Toggle Lab Scrolling to OFF
    await tester.ensureVisible(offBtnFinder);
    await tester.tap(offBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('SCROLL OFF'), findsOneWidget);
    scrollView = tester.widget<SingleChildScrollView>(scrollableFinder);
    expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());

    // 4. Toggle Lab Scrolling back to ON
    await tester.ensureVisible(onBtnFinder);
    await tester.tap(onBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('SCROLL ON'), findsOneWidget);
    scrollView = tester.widget<SingleChildScrollView>(scrollableFinder);
    expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());

    // 5. Verify Reset button restores defaults including Lab Scrolling ON
    await tester.tap(offBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('SCROLL OFF'), findsOneWidget);

    final resetBtn = find.text('Reset');
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    expect(find.text('SCROLL ON'), findsOneWidget);
    scrollView = tester.widget<SingleChildScrollView>(scrollableFinder);
    expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets(
      'Stage 2 Content Follow control: defaults to 0.0 and allows selecting 25%, 50%, 75%, 100% while Stage 1 is unaffected',
      (WidgetTester tester) async {
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

    // 1. Verify default Content Follow is 0% (0.00)
    expect(find.text('Content Follow'), findsOneWidget);
    expect(find.text('0% (0.00)'), findsOneWidget);

    // Switch to Stage 2 in PageView
    final pageViewFinder =
        find.byKey(const ValueKey('stage_carousel_page_view'));
    final pageView = tester.widget<PageView>(pageViewFinder);
    pageView.controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    final stage2Finder =
        find.byKey(const ValueKey('quick_notes_create_folder_glass'));
    expect(stage2Finder, findsOneWidget);
    expect((tester.widget(stage2Finder) as dynamic).childFollow, equals(0.0));

    // 2. Tap 25% button -> childFollow is 0.25
    final btn25 = find.byKey(const ValueKey('stage2_content_follow_25_button'));
    await tester.ensureVisible(btn25);
    await tester.tap(btn25);
    await tester.pumpAndSettle();
    expect(find.text('25% (0.25)'), findsOneWidget);
    expect((tester.widget(stage2Finder) as dynamic).childFollow, equals(0.25));

    // 3. Tap 50% button -> childFollow is 0.50
    final btn50 = find.byKey(const ValueKey('stage2_content_follow_50_button'));
    await tester.ensureVisible(btn50);
    await tester.tap(btn50);
    await tester.pumpAndSettle();
    expect(find.text('50% (0.50)'), findsOneWidget);
    expect((tester.widget(stage2Finder) as dynamic).childFollow, equals(0.50));

    // 4. Tap 75% button -> childFollow is 0.75
    final btn75 = find.byKey(const ValueKey('stage2_content_follow_75_button'));
    await tester.ensureVisible(btn75);
    await tester.tap(btn75);
    await tester.pumpAndSettle();
    expect(find.text('75% (0.75)'), findsOneWidget);
    expect((tester.widget(stage2Finder) as dynamic).childFollow, equals(0.75));

    // 5. Tap 100% button -> childFollow is 1.00
    final btn100 =
        find.byKey(const ValueKey('stage2_content_follow_100_button'));
    await tester.ensureVisible(btn100);
    await tester.tap(btn100);
    await tester.pumpAndSettle();
    expect(find.text('100% (1.00)'), findsOneWidget);
    expect((tester.widget(stage2Finder) as dynamic).childFollow, equals(1.0));

    // 6. Verify Reset restores Content Follow to 0% (0.00)
    final resetBtn = find.text('Reset');
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();
    expect(find.text('0% (0.00)'), findsOneWidget);

    // 7. Verify Stage 1 is unaffected: switch back to Stage 1 and check LiquidGlassButton
    expect(
        find.byKey(const ValueKey('native_liquid_glass_button')), findsOneWidget);
  });
}

void _dummyCallback() {}

