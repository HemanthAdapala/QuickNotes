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
  });
}
