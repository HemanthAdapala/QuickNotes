import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:quick_notes/liquid_glass_catalog/liquid_glass_catalog_screen.dart';

void main() {
  testWidgets(
      'LiquidGlassCatalogScreen renders minimal component index and navigates to detail experiment',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        brightnessResolver: Theme.maybeBrightnessOf,
        child: const MaterialApp(
          home: LiquidGlassCatalogScreen(),
        ),
      ),
    );

    // Verify main index header and categories
    expect(find.text('LIQUID GLASS'), findsOneWidget);
    expect(find.text('Buttons'), findsOneWidget);
    expect(find.text('Containers'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Surfaces'), findsOneWidget);

    // Verify component rows exist
    expect(find.text('Glass Button'), findsOneWidget);
    expect(find.text('Glass Card'), findsOneWidget);
    expect(find.text('Glass Switch'), findsOneWidget);
    expect(find.text('Glass Tab Bar'), findsOneWidget);

    // Tap Glass Button to open dedicated experiment
    await tester.tap(find.text('Glass Button'));
    await tester.pumpAndSettle();

    // Verify detail screen content
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Launch Action'), findsOneWidget);

    // Tap back button to return to catalog index
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Verify back on main index
    expect(find.text('LIQUID GLASS'), findsOneWidget);

    // Scroll to reveal Optical Effects category
    await tester.scrollUntilVisible(
      find.text('Optical Effects'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Optical Effects'), findsOneWidget);

    // Verify all 6 optical effect entries exist
    expect(find.text('Blur'), findsOneWidget);
    expect(find.text('Refraction'), findsOneWidget);
    expect(find.text('Distortion'), findsOneWidget);
    expect(find.text('Magnification'), findsOneWidget);
    expect(find.text('Specular Highlight'), findsOneWidget);
    expect(find.text('Chromatic Aberration'), findsOneWidget);

    // Tap Blur to open dedicated optical experiment
    await tester.tap(find.text('Blur'));
    await tester.pumpAndSettle();
    expect(find.text('API: LiquidGlassSettings.blur'), findsOneWidget);
    expect(find.text('Blur Radius'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Tap Chromatic Aberration to open dedicated optical experiment
    await tester.scrollUntilVisible(
      find.text('Chromatic Aberration'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Chromatic Aberration'));
    await tester.pumpAndSettle();
    expect(
      find.text('API: LiquidGlassSettings.chromaticAberration'),
      findsOneWidget,
    );
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Tap Specular Highlight to open dedicated optical experiment
    await tester.scrollUntilVisible(
      find.text('Specular Highlight'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Specular Highlight'));
    await tester.pumpAndSettle();
    expect(find.text('soft (diffuse)'), findsOneWidget);
    expect(find.text('medium (default)'), findsOneWidget);
    expect(find.text('sharp (tight)'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Final check that we returned to catalog index
    expect(find.text('LIQUID GLASS'), findsOneWidget);

    // Scroll to reveal Interaction category
    await tester.scrollUntilVisible(
      find.text('Interaction'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Interaction'), findsOneWidget);

    // Verify all 6 interaction entries exist
    expect(find.text('Press Response'), findsOneWidget);
    expect(find.text('Touch Glow'), findsOneWidget);
    expect(find.text('Drag Stretch'), findsOneWidget);
    expect(find.text('Interactive Indicator'), findsOneWidget);
    expect(find.text('Component Physics'), findsOneWidget);
    expect(find.text('Optical Interaction'), findsOneWidget);

    // Tap Press Response to open dedicated interaction experiment
    await tester.tap(find.text('Press Response'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Public API: GlassButton.interactionScale\nInternal Mechanism: LiquidStretch spring scale',
      ),
      findsOneWidget,
    );
    expect(find.text('Interaction Scale Factor'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Tap Touch Glow to open dedicated interaction experiment
    await tester.scrollUntilVisible(
      find.text('Touch Glow'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Touch Glow'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Public API: GlassGlow, GlassInteractionBehavior\nInternal Mechanism: Touch coordinate tracking to radial glow pass',
      ),
      findsOneWidget,
    );
    expect(find.text('GlassInteractionBehavior'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Tap Interactive Indicator to open dedicated interaction experiment
    await tester.scrollUntilVisible(
      find.text('Interactive Indicator'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Interactive Indicator'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Public API: AnimatedGlassIndicator, indicatorPinchStrength\nInternal Mechanism: DraggableIndicatorPhysics jelly transform, shader pinch',
      ),
      findsOneWidget,
    );
    expect(find.text('Indicator Pinch Strength'), findsOneWidget);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Final check that we returned to catalog index
    expect(find.text('LIQUID GLASS'), findsOneWidget);

    // Scroll to reveal Performance category
    await tester.scrollUntilVisible(
      find.text('Performance'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Performance'), findsOneWidget);

    // Verify all 9 performance scenario entries exist
    expect(find.text('01 — Baseline'), findsOneWidget);
    expect(find.text('02 — Surface Count'), findsOneWidget);
    expect(find.text('03 — Blur Cost'), findsOneWidget);
    expect(find.text('04 — Refraction Cost'), findsOneWidget);
    expect(find.text('05 — Chromatic Aberration Cost'), findsOneWidget);
    expect(find.text('06 — Specular / Fresnel Cost'), findsOneWidget);
    expect(find.text('07 — Interaction Cost'), findsOneWidget);
    expect(find.text('08 — Interactive Indicator Cost'), findsOneWidget);
    expect(find.text('09 — Quality Modes'), findsOneWidget);

    // Tap 01 — Baseline to open dedicated benchmark screen
    await tester.tap(find.text('01 — Baseline'));
    await tester.pumpAndSettle();
    expect(find.text('PERFORMANCE QUESTION'), findsOneWidget);
    expect(find.text('REPRODUCIBILITY METADATA'), findsOneWidget);
    expect(find.text('LIVE TELEMETRY (ROLLING 60 FRAMES)'), findsOneWidget);
    expect(find.text('Hide Telemetry'), findsOneWidget);
    // Tap back button
    await tester.tap(find.byTooltip('Return to Catalog Index'));
    await tester.pumpAndSettle();

    // Tap 02 — Surface Count to open dedicated benchmark screen
    await tester.scrollUntilVisible(
      find.text('02 — Surface Count'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('02 — Surface Count'));
    await tester.pumpAndSettle();
    expect(find.text('1 Surface'), findsOneWidget);
    expect(find.text('4 Surfaces'), findsOneWidget);
    expect(find.text('16 Surfaces'), findsOneWidget);
    await tester.tap(find.byTooltip('Return to Catalog Index'));
    await tester.pumpAndSettle();

    // Tap 09 — Quality Modes to open dedicated benchmark screen
    await tester.scrollUntilVisible(
      find.text('09 — Quality Modes'),
      100.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('09 — Quality Modes'));
    await tester.pumpAndSettle();
    expect(find.text('Minimal (BackdropFilter)'), findsOneWidget);
    expect(find.text('Standard (Lightweight)'), findsOneWidget);
    expect(find.text('Premium (Multi-Pass)'), findsOneWidget);
    await tester.tap(find.byTooltip('Return to Catalog Index'));
    await tester.pumpAndSettle();

    // Final check that we returned to catalog index
    expect(find.text('LIQUID GLASS'), findsOneWidget);
  });
}

