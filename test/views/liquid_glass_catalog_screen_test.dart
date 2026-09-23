import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:quick_notes/liquid_glass_catalog/liquid_glass_catalog_screen.dart';

void main() {
  testWidgets('LiquidGlassCatalogScreen renders and supports category switching',
      (WidgetTester tester) async {
    // Wrap in MaterialApp with LiquidGlassWidgets.wrap
    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        brightnessResolver: Theme.maybeBrightnessOf,
        child: const MaterialApp(
          home: LiquidGlassCatalogScreen(),
        ),
      ),
    );

    // Verify title and initial section (Containers)
    expect(find.text('Liquid Glass Catalog'), findsOneWidget);
    expect(find.text('Containers'), findsOneWidget);
    expect(find.text('Interactive'), findsOneWidget);
    expect(find.text('Surfaces'), findsOneWidget);

    // Verify GlassContainer & GlassCard demo presence
    expect(find.text('GlassContainer'), findsOneWidget);
    expect(find.text('GlassCard'), findsOneWidget);

    // Switch to Interactive category
    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();

    // Verify Interactive components appear
    expect(find.text('GlassButton & GlassButton.custom'), findsOneWidget);
    expect(find.text('GlassSwitch'), findsOneWidget);
    expect(find.text('GlassSlider'), findsOneWidget);

    // Switch to Surfaces category
    await tester.tap(find.text('Surfaces'));
    await tester.pumpAndSettle();

    // Verify Surfaces components appear
    expect(find.text('GlassAppBar (Structural)'), findsOneWidget);
    expect(find.text('GlassTabBar.bottom (Structural)'), findsOneWidget);
  });
}
